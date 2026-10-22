package local.leica.sr;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;

/** Build266 companion: relocate only the verified private SDK config string. */
public final class HarboPrivateConfig {
    static final String LIB = "/data/vendor/camera/leica-moment-nezha28/raw-original-100/libmialgo_hdsr_sr.so";
    static final String HASH = "f323c95e7ddcf420a27b6ddb13b2651f64176498f0c88990013103f5c82676e4";
    static final String HARBO_LIB = "/data/vendor/camera/leica-moment-nezha28/raw-original-100/libharbo.so";
    static final String HARBO_HASH = "68be9d011405c4bf442838c8938a3c31232dc5df29bc37a2b169f3cfd802c93d";
    static final byte[] OLD = "/odm/etc/camera/harbo_sr_config.json\0".getBytes(StandardCharsets.US_ASCII);
    static final byte[] NEW = Arrays.copyOf("/data/vendor/lc/harbo.json\0".getBytes(StandardCharsets.US_ASCII), OLD.length);
    static final long RVA = 0x2b0b99L;

    static String hash(String path) throws Exception {
        MessageDigest h = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new FileInputStream(path)) {
            byte[] b = new byte[65536]; int n;
            while ((n = in.read(b)) != -1) h.update(b, 0, n);
        }
        StringBuilder result = new StringBuilder();
        for (byte b : h.digest()) result.append(String.format(Locale.ROOT, "%02x", b & 255));
        return result.toString();
    }
    static void owner(String pid, String ticks) throws Exception {
        byte[] cmd = Files.readAllBytes(Paths.get("/proc/" + pid + "/cmdline"));
        int end = 0; while (end < cmd.length && cmd[end] != 0) end++;
        String argv = new String(cmd, 0, end, StandardCharsets.US_ASCII);
        if (!argv.equals("/odm/bin/hw/vendor.qti.camera.provider-service_64")) throw new Exception("provider identity");
        String stat = new String(Files.readAllBytes(Paths.get("/proc/" + pid + "/stat")), StandardCharsets.US_ASCII);
        int close = stat.lastIndexOf(')');
        if (close < 0) throw new Exception("provider stat");
        String[] fields = stat.substring(close + 2).trim().split(" +");
        if (fields.length <= 19 || !fields[19].equals(ticks)) throw new Exception("provider generation");
    }
    static long address(List<String> maps) throws Exception {
        long base = -1;
        for (String line : maps) {
            String[] f = line.trim().split("\\s+", 6);
            if (f.length == 6 && f[5].equals(LIB) && f[1].contains("x") && Long.parseUnsignedLong(f[2],16) == 0) {
                if (base != -1) throw new Exception("ambiguous private SDK");
                base = Long.parseUnsignedLong(f[0].split("-")[0],16);
            }
        }
        if (base == -1) throw new Exception("private SDK not loaded");
        long address = base + RVA;
        for (String line : maps) {
            String[] f = line.trim().split("\\s+",6);
            if (f.length != 6 || !f[5].equals(LIB) || !f[1].equals("r--p")) continue;
            String[] r = f[0].split("-");
            if (address >= Long.parseUnsignedLong(r[0],16) && address + OLD.length <= Long.parseUnsignedLong(r[1],16)) return address;
        }
        throw new Exception("config string outside private rodata");
    }
    static String state(byte[] bytes) throws Exception {
        if (Arrays.equals(bytes,OLD)) return "original";
        if (Arrays.equals(bytes,NEW)) return "relocated";
        throw new Exception("config string mismatch");
    }
    public static void main(String[] a) {
        try {
            if (a.length == 1 && a[0].equals("--self-test")) { selfTest(); return; }
            run(a);
        } catch (Exception e) { System.err.println("PRIVATE_HARBO_REJECTED " + e.getMessage()); System.exit(1); }
    }
    static void run(String[] a) throws Exception {
        if (a.length != 3 || !Arrays.asList("--check","--verify-relocated","--apply","--restore").contains(a[0]) ||
            !a[1].matches("[0-9]+") || !a[2].matches("[0-9]+")) throw new Exception("arguments");
        int uid = (Integer)Class.forName("android.os.Process").getMethod("myUid").invoke(null);
        if (uid != 0) throw new Exception("root required");
        String pid = a[1], ticks = a[2];
        owner(pid,ticks);
        if (!hash(LIB).equals(HASH)) throw new Exception("private SDK checksum");
        if (!hash(HARBO_LIB).equals(HARBO_HASH)) throw new Exception("private Harbo checksum");
        long address = address(Files.readAllLines(Paths.get("/proc/"+pid+"/maps"),StandardCharsets.US_ASCII));
        boolean check = a[0].equals("--check") || a[0].equals("--verify-relocated"), restore = a[0].equals("--restore");
        try (RandomAccessFile mem = new RandomAccessFile("/proc/"+pid+"/mem",check ? "r" : "rw")) {
            byte[] before = new byte[OLD.length]; mem.seek(address); mem.readFully(before);
            String state = state(before);
            if (a[0].equals("--verify-relocated") && !state.equals("relocated")) throw new Exception("private path reverted");
            if (check) { owner(pid,ticks); System.out.println("PRIVATE_HARBO_CHECK "+state); return; }
            byte[] replacement = restore ? OLD : NEW;
            if (!Arrays.equals(before,replacement)) {
                owner(pid,ticks); mem.seek(address); mem.write(replacement);
                mem.seek(address); mem.readFully(before);
                if (!Arrays.equals(before,replacement)) throw new Exception("config readback mismatch");
            }
        }
        owner(pid,ticks);
        System.out.println("PRIVATE_HARBO_CONFIG_READY "+(restore ? "original" : "relocated"));
    }
    interface Test { void run() throws Exception; }
    static void rejects(Test test) throws Exception {
        boolean rejected = false;
        try { test.run(); } catch (Exception expected) { rejected = true; }
        if (!rejected) throw new Exception("self-test failed to reject");
    }
    static void selfTest() throws Exception {
        final List<String> valid = Arrays.asList(
            "10000000-10010000 r-xp 00000000 00:01 1 "+LIB,
            "10200000-10300000 r--p 00200000 00:01 1 "+LIB);
        if (address(valid) != 0x10000000L+RVA) throw new Exception("self-test address");
        rejects(()->address(Collections.singletonList(valid.get(0))));
        rejects(()->address(Arrays.asList(valid.get(0),valid.get(0),valid.get(1))));
        rejects(()->address(Arrays.asList(valid.get(0),valid.get(1).replace("r--p","rw-p"))));
        rejects(()->address(Arrays.asList(valid.get(0),valid.get(1).replace(LIB,"/odm/lib64/libmialgo_hdsr_sr.so"))));
        if (!state(OLD).equals("original") || !state(NEW).equals("relocated")) throw new Exception("self-test state");
        byte[] bad = NEW.clone(); bad[0] ^= 1;
        rejects(()->state(bad));
        if (NEW.length != OLD.length || NEW[NEW.length-1] != 0) throw new Exception("self-test padding");
        System.out.println("PASS: SDK identity, map ambiguity, rodata bounds/protection, exact strings and zero padding");
    }
}
