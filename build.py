"""Build the build266-only independent KernelSU companion; no device actions."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,zipfile
os.sys.stdout.reconfigure(encoding='utf-8')

BASE=Path(__file__).resolve().parent
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(args,**kwargs):
    result=subprocess.run([str(x) for x in args],capture_output=True,**kwargs)
    output=(result.stdout+result.stderr).decode('utf-8','replace')
    if result.returncode:raise RuntimeError(output)
    return output

def fixtures(out):
    root=out/'fixtures';root.mkdir(exist_ok=True)
    private=root/'first-install-private'
    if (private/'harbo.json').is_file():(private/'harbo.json').unlink()
    if private.is_dir():private.rmdir()
    owner=root/'owner';owner.mkdir(exist_ok=True)
    names=['myron-os4040','pandora-os4020','pandora','popsicle-os4020','popsicle','pudding-os4020','pudding-os4040','pudding']
    (owner/'module.prop').write_text('versionCode=266\n',encoding='ascii')
    for file in ['service.sh','session.sh','platform.sh','root-runtime.sh','harbo/harbo_sr_config.json']:
        p=owner/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fixture:'+file+'\n',encoding='ascii')
    for name in names:
        view=root/'views'/name
        (view/'lib64/hw').mkdir(parents=True,exist_ok=True);(view/'etc/camera').mkdir(parents=True,exist_ok=True)
        core=view/'lib64/hw/camera.qcom.core.so';core.write_text('fixture core '+name,encoding='ascii')
        conf=view/'etc/camera/harbo_sr_config.json';conf.write_text(json.dumps({'fixture_profile':name}),encoding='ascii')
        profile=owner/'profiles'/name;(profile/'scripts').mkdir(parents=True,exist_ok=True)
        (profile/'core.sha256').write_text(digest(core)+'\n',encoding='ascii')
        (profile/'stock-config.sha256').write_text(digest(conf)+'  harbo_sr_config.json\n',encoding='ascii')
        (profile/'stock-native.sha256').write_text(digest(core)+'  lib64/hw/camera.qcom.core.so\n',encoding='ascii')
        (profile/'scripts/native.js').write_text('// fixture '+name+'\n',encoding='ascii')
    reindex=BASE/'tests/reindex.py'
    run([os.sys.executable,reindex,owner])
    return root

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--jdk',default=os.environ.get('JAVA_HOME'))
    p.add_argument('--sdk',default=os.environ.get('ANDROID_SDK_ROOT'))
    p.add_argument('--platform',default='android-37.0');p.add_argument('--build-tools',default='37.0.0')
    p.add_argument('--sh',default=shutil.which('sh'));p.add_argument('--test',action='store_true')
    a=p.parse_args()
    if not a.jdk or not a.sdk:p.error('Provide --jdk and --sdk, or JAVA_HOME and ANDROID_SDK_ROOT.')
    suffix='.exe' if os.name=='nt' else ''
    jdk=Path(a.jdk)/'bin';sdk=Path(a.sdk)
    javac=jdk/('javac'+suffix);java=jdk/('java'+suffix)
    android=sdk/'platforms'/a.platform/'android.jar';d8=sdk/'build-tools'/a.build_tools/'lib/d8.jar'
    for file in [javac,java,android,d8]:
        if not file.is_file():p.error('Missing tool: '+str(file))
    out=BASE/'build';out.mkdir(exist_ok=True)
    classes=out/'classes';classes.mkdir(exist_ok=True)
    report={}
    report['javac']=run([javac,'-encoding','UTF-8','--release','8','-Xlint:-options','-d',classes,BASE/'module/HarboPrivateConfig.java'])
    report['java_guards']=run([java,'-cp',classes,'local.leica.sr.HarboPrivateConfig','--self-test'])
    if a.test:
        if not a.sh:p.error('--test requires --sh pointing to a POSIX shell.')
        for file in sorted((BASE/'module').glob('*.sh')):
            run([a.sh,'-n',file.as_posix()])
        report['shell_syntax']='PASS: all module shell files'
        root=fixtures(out)
        env=os.environ.copy();env['PYTHON_EXE']=os.sys.executable.replace('\\','/')
        env['HASH_HELPER']=(BASE/'tests/hash_file.py').as_posix()
        env['REINDEX_HELPER']=(BASE/'tests/reindex.py').as_posix()
        env['HOST_TOOLS']=(BASE/'tests/host_tools.py').as_posix()
        env['PATH']=str(Path(a.sh).parent)+os.pathsep+env.get('PATH','')
        report['profile_guards']=run([a.sh,'tests/test_logic.sh'],cwd=BASE,env=env)
    classjar=out/'helper-classes.jar'
    with zipfile.ZipFile(classjar,'w',zipfile.ZIP_DEFLATED) as z:
        for file in sorted(classes.rglob('*.class')):z.write(file,file.relative_to(classes).as_posix())
    helper=out/'helper.jar'
    run([java,'-cp',d8,'com.android.tools.r8.D8','--lib',android,'--min-api','29','--output',helper,classjar])
    with zipfile.ZipFile(helper) as z:assert z.testzip() is None and z.read('classes.dex').startswith(b'dex\n')
    mod=out/'module';shutil.copytree(BASE/'module',mod,dirs_exist_ok=True);shutil.copy2(helper,mod/'helper.jar')
    for file in mod.iterdir():
        if file.is_file() and file.suffix in ('.sh','.java','.md','.prop','.json'):
            file.write_bytes(file.read_bytes().replace(b'\r\n',b'\n'))
    entries=sorted(x for x in mod.iterdir() if x.is_file() and x.name!='files.sha256')
    (mod/'files.sha256').write_text(''.join(digest(f)+'  '+f.name+'\n' for f in entries),encoding='ascii',newline='\n')
    dest=out/'Leica-0.266-native-SR-split-1.2.0-candidate.zip'
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as z:
        for file in sorted(mod.iterdir()):
            if file.is_file():z.write(file,file.name)
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
        for line in z.read('files.sha256').decode().splitlines():
            sha,name=line.split('  ',1);assert hashlib.sha256(z.read(name)).hexdigest()==sha
    report['package_sha256']=digest(dest)
    report['device_validation']='Pending connected Xiaomi 17 Pro validation; host tests do not prove other devices.'
    (out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
    print(json.dumps(report,ensure_ascii=False,indent=2));print(dest)
if __name__=='__main__':main()
