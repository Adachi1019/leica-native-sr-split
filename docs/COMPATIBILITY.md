# 固件与算法指纹适配范围

范围固定为原版 Leica 0.266 的八个配置档。设备名称和配置档后缀不能代替真实指纹检查。以下所有索引均从本次原版 0.266 清单核对；仅 pandora-os4020 经过实机验证。

| 配置档 | 原厂相机核心 SHA-256 | 原厂 Harbo JSON SHA-256 |
| --- | --- | --- |
| `myron-os4040` | `85ffbc63c91b33121818f4fa9295ec02d503242f3608808248700257efd8398d` | `4adc6f94a4efc12876ad30dd8edd08a94db690cde5ef04f929d3db20bdf03b3f` |
| `pandora` | `07578081d35ae6e038e2accf85f52cb6eac788a2c1b188791db28b64a9f64f0a` | `6d87902393451786a14e99860c90b1b420845fabb8750c38d4b0d3a4fcae712a` |
| `pandora-os4020` | `8801045d95b738b427c70789a3e6c08b0a1608a49655c39e8785dd0005acddc2` | `6d87902393451786a14e99860c90b1b420845fabb8750c38d4b0d3a4fcae712a` |
| `popsicle` | `be4bdd94740895ccedcfba56ca6708935017c10d0022a9456cf65742512e8a6a` | `fe0bb259ad1a95c3d3d9e263403e649afa40c7068c3696dd514da79f9702e54e` |
| `popsicle-os4020` | `7f8cfccd86f76784218c5c82f41af21f34bfbdf5978e12c223499d82f2ff4c9e` | `fe0bb259ad1a95c3d3d9e263403e649afa40c7068c3696dd514da79f9702e54e` |
| `pudding` | `6e23f0b0cb89bcdae0042fcd33351d971195157d1ea32f2d763ee50b5832c65f` | `83c71a017c90e9dcadc717ac4214f7ef7d885b59a90f71fbb030af171b139a53` |
| `pudding-os4020` | `fe5b36c328f61e60dc85c0a258dcfbb933d7f5633e1fab941a0e9d6efa9c8b34` | `83c71a017c90e9dcadc717ac4214f7ef7d885b59a90f71fbb030af171b139a53` |
| `pudding-os4040` | `f572f77efbe2c912b8b2c5541c47aa013d6cf9befa76a58793caa1b49dc1faf6` | `83c71a017c90e9dcadc717ac4214f7ef7d885b59a90f71fbb030af171b139a53` |

安装时从非递归、只读的 `/odm` 临时绑定视图读取原厂文件，避开原模块的子挂载。安装器只接受唯一核心匹配项，再以该档原厂配置清单校验本机 JSON。不会将一部 17 Pro 的 JSON 提供给其他机型。

运行时还会核对固定原模块清单、相关脚本、私有库哈希、相机进程身份与启动代次、私有只读内存区域、目标字节及只读挂载归属。原徕卡模块升级后需要重新核实与适配；本包不自动放宽版本限制。

仓库旧版 248 中的 popsicle-os40040 属于 17 Pro Max 的旧固件配置，0.266 未提供该档，本补丁不补造相应运行数据。其他固件与 POCO 等同代号变体也不能只按商品名认定兼容，以所有检查通过为准。
