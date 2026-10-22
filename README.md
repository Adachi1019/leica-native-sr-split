# Leica Native SR Split · 原相机算法配置分离修复

为 **Leica camera 0.266 / build266** 制作的独立 **KernelSU 配套补丁**。将普通相机的原厂 Harbo SR 配置与徕卡一瞬的私有 P1 配置分开，使两条处理路径使用各自需要的配置。

当前版本：**1.2.0-candidate**。**小米 17 Pro 的 pandora-os4020 配置档已完成实机验证**；其余配置档通过主机保护逻辑与清单核对，仍待对应手机实拍。

[下载刷入包与源码](https://github.com/Adachi1019/leica-native-sr-split/releases/tag/v1.2.0-candidate) · [适配条件与指纹](docs/COMPATIBILITY.md) · [实机验证](docs/VALIDATION.md) · [构建方法](docs/BUILD.md)

## 修复内容

原徕卡模块将私有 P1 `harbo_sr_config.json` 放在全局相机配置路径。普通模式使用的原厂 Harbo 库可能需要另一份配置，从而发生算法初始化或处理异常。

本补丁从设备未被模块覆盖的原厂分区视图提取并核实该设备自己的配置，以只读挂载供普通相机使用；仅将已核实的私有 SDK 内存配置路径转向独立 P1 JSON。原模块的 M9 校正、APK、算法库磁盘文件与签名校验保留。

本仓库只发布独立补丁，不包含厂商算法源码、模型、相机 APK、完整徕卡模块或原始项目私有源码。

## 适配范围

覆盖本次核实的原版 **0.266 所附全部 8 个配置档，涉及 4 款机型**：

| 机型 | 配置档 | 本次验证范围 |
| --- | --- | --- |
| 小米 17 | `pudding`、`pudding-os4020`、`pudding-os4040` | 清单核对、主机模拟；待实拍 |
| 小米 17 Pro | `pandora`、`pandora-os4020` | **仅 `pandora-os4020` 已实拍通过**；`pandora` 待实拍 |
| 小米 17 Pro Max | `popsicle`、`popsicle-os4020` | 清单核对、主机模拟；待实拍 |
| Redmi K90 Pro Max | `myron-os4040` | 清单核对、主机模拟；待实拍 |

**同名机型的任意固件不一定适用。** 安装器依据真实原厂 `camera.qcom.core.so` 指纹唯一选择配置档，再验证本机原厂 JSON；机型属性仅用于显示。配置档名称不等于当前系统版本，例如本次 OS4.0.4.0 的 17 Pro 实际匹配 `pandora-os4020`。

需要已启用本次固定运行清单对应的 Leica 0.266 原模块及 KernelSU。不同徕卡版本、不同运行清单、未知或冲突核心、配置不匹配时拒绝安装/应用；私有 SDK 哈希、进程身份、内存映射或原字节不匹配时停止应用。旧版 248 的 `popsicle-os40040` 不在本次 0.266 配置集中，不使用旧数据强行适配。

## 安装

1. 保持已适配设备的原 Leica **0.266** 模块启用。
2. 从 [Release](https://github.com/Adachi1019/leica-native-sr-split/releases/tag/v1.2.0-candidate) 下载 `Leica-0.266-native-SR-split-1.2.0-candidate.zip`，可对照同页 `SHA256SUMS.txt`。
3. 在 KernelSU 中安装该 ZIP。安装器会自动选择配置档并显示结果，无需手选机型。
4. 重启手机并解锁一次，等待原徕卡模块就绪后补丁自动应用。
5. 在模块“操作”中查看状态，并实拍普通照片和徕卡一瞬照片，等待最终成片保存。

模块 ID 为 `leica_ordinary_sr_fix`，会按正常更新方式替换旧配套补丁。不要将 GitHub 自动生成的仓库源码压缩包当作可刷入 ZIP。

## 状态和撤销

状态目录：`/data/adb/leica-stock-sr-266/`。

- `waiting-owner`：等待原徕卡模块就绪，开机初始化可能需要一段时间。
- `ready:<PID>:<启动时间>:<配置档>:stock-native+private-p1`：配置、内存路径、只读挂载与提供者可见性检查通过，仍需实拍确认效果。
- `unsupported:` / `rejected-` / `failed-`：按具体原因检查版本、清单与固件，保留保护检查，不强行跳过。

相机服务重启后会等待原模块就绪并重新应用。补丁自身默认不启用详细拍照日志、不读取照片、不联网。

**撤销：**在 KernelSU 停用或卸载本配套补丁并重启。内存路径和配置挂载随重启消失，恢复原徕卡模块的行为；原配置冲突也可能再次出现。照片与相册数据保留，少量配置缓存及可能仍被当前进程引用的私有 JSON 会保留。

## 已验证结果

2026-10-22，小米 17 Pro / `pandora` / OS4.0.4.0.XBLCNXM，自动选择 `pandora-os4020`：

- 普通 1×：`aisp_hdr`，8 帧，`Bypass=0`、`ProcessRet=0`，收到最终照片及保存完成回调。
- 普通 10×：`aisp_sr`，8 帧，Harbo 2.1.2 初始化与处理均成功，收到最终照片及保存完成回调。
- 徕卡一瞬 10×：原 Legend/M9 执行事件与最终保存回调均已观察到，用户确认处理后成片正常。
- 正常安装、重启、解锁后自动生效；拍照前后原徕卡模块 186 项运行文件完整性检查通过，详细日志属性恢复原值。

其余 7 档尚未实机验证。详细范围见 [验证记录](docs/VALIDATION.md)。

## 源码与来源

`module/` 为独立补丁源码，`build.py` 与 `tests/` 提供构建和主机保护测试。模块 ZIP 可通过校验清单核对；源码与发布包的模块文件逐项比对记录见 [构建与发布说明](docs/BUILD.md)。

原 Leica 模块作者按模块元数据为酷安 kobbin。参考项目为 [lenowo/m17-camera-port](https://github.com/lenowo/m17-camera-port)，参考快照为 `work/release266-source`（观察提交 `9389fe9`）；该仓库可能需要访问权限。本独立仓库不修改原项目，也不提供原模块下载。来源与固定哈希见 [PROVENANCE.json](PROVENANCE.json)。

反馈兼容性时请提供机型、系统版本、原徕卡版本、选择的配置档与结构状态，并说明普通/徕卡一瞬是否已得到最终成片；无需上传照片、设备序列号或原始完整诊断包。
