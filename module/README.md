# 徕卡 0.266 原相机算法配置分离补丁

版本 1.2.0-candidate，KernelSU 自动识别版。保持原徕卡 0.266 模块启用，安装本 ZIP 后重启并解锁。

普通相机使用设备自己的原厂 Harbo 配置；徕卡一瞬的已核实私有 SDK 单独使用 P1 配置。保留原模块的 M9 色彩校正、APK、算法库及签名校验，不修改 GitHub 仓库。

| 机型 | 最新 0.266 提供的配置档 |
| --- | --- |
| 小米 17 | pudding、pudding-os4020、pudding-os4040 |
| 小米 17 Pro | pandora、pandora-os4020 |
| 小米 17 Pro Max | popsicle、popsicle-os4020 |
| Redmi K90 Pro Max | myron-os4040 |

上述覆盖本次已安装的原版 0.266 全部八档。仓库旧版 248 中还有 popsicle-os40040，仍属 17 Pro Max，但 0.266 没有该档；不能拿旧版指纹冒充新版支持，也不代表上述机型的任意固件可用。

安装器使用未被模块覆盖的原厂 camera.qcom.core.so 指纹，唯一匹配配置档，再检查该设备原厂 harbo_sr_config.json 的 SHA-256。不是只看机型名，包内不附带通用原厂 JSON。错误版本、未知或冲突指纹、不同配置或私有算法库会拒绝应用。

首次安装会创建独立私有配置目录，不依赖旧补丁。模块 ID 为 leica_ordinary_sr_fix，会正常替换旧配套补丁。运行状态在 /data/adb/leica-stock-sr-266/status；ready:<PID>:<启动时间>:<配置档>:stock-native+private-p1 代表挂载和内存路径检查通过。相机服务重启后自动重新应用。

停用本补丁并重启即可撤销，照片和相册数据保留。缓存与可能仍被当前算法引用的小型私有 JSON 会保留。原徕卡模块升级到其他版本后，本补丁自动拒绝运行，需要重新适配。

源码依据：只读查看 https://github.com/lenowo/m17-camera-port 主分支 9389fe9 的 work/release266-source，按 SOURCE_MANIFEST.json 验证 P.java、NativeControls.java。该目录仅有应用源码，完整运行清单和八档配置校验清单来自本次手机上原版 0.266 的只读提取。未使用其他版本运行文件代替。详见 PROVENANCE.json。

构建依赖 Python 3.10+、JDK 21、Android SDK Platform android-37.0、Build Tools 37.0.0、POSIX sh/awk：

```powershell
python build.py --jdk C:\path\to\jdk --sdk D:\path\to\sdk --sh C:\path\to\sh.exe --test
```

主机验证覆盖八档选择、错误版本、被改动清单、未知与冲突指纹、挂载归属、私有目录首次创建、内存地址与字节保护。主机测试不能证明其他手机的成片。小米 17 Pro 本次实机验证结果另见随包验证记录；其余机型须实拍确认。源码包不包含厂商算法源码、模型、相机 APK 或完整徕卡模块。
