# 构建与发布

依赖 Python 3.10+、JDK 21、Android SDK Platform android-37.0、Build Tools 37.0.0。主机测试还需 POSIX sh 和 awk。Windows 可使用带 sh.exe / awk.exe 的 Git 运行环境，测试内的辅助工具补足缺少的部分核心工具；SELinux/权限检查另经 Android 验证。

```powershell
python build.py --jdk "C:\path\to\jdk-21" --sdk "D:\path\to\sdk" --sh "C:\path\to\sh.exe" --test
```

Linux/macOS 同样传入本机 JDK、Android SDK 与 sh 路径。输出位于 build/，其中 Leica-0.266-native-SR-split-1.2.0-candidate.zip 是可安装包。GitHub 自动生成的 Source code ZIP 不能刷入。

build.py 编译 Java、运行保护自检、按需执行 Shell 测试、使用 D8 生成 helper.jar，并为模块生成 files.sha256。ZIP 时间戳可能随环境变化，因此本地重新构建不保证 ZIP 字节哈希一致。

发布的刷入包与已安装验证的包字节一致，SHA-256 为：

```text
b5ffa7be32fbe3a48e548702a08ab68f915cbd6094446a947a67094f2a77470f
```

本次发布前已检查 ZIP CRC、files.sha256，逐项比对仓库 module/ 与发布 ZIP 的源码内容，并检查 helper.jar 内含 DEX。helper.jar 来自该 Java 源码的已验证构建。KernelSU 安装后会移除安装专用 customize.sh、README.md；运行完整性核对时排除这两项，不误判为运行文件损坏。

公开源码包由本仓库发布内容生成，未带入本机诊断目录、原始运行快照、手机备份或上游应用源码。发布资产的 SHA256SUMS.txt 覆盖刷入包、独立源码包及公开验证记录。
