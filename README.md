# ImmortalWrt H5000M 自动编译

[![Build](https://github.com/existyay/Auto-H5000M-BIN/actions/workflows/build-test.yml/badge.svg)](https://github.com/existyay/Auto-H5000M-BIN/actions/workflows/build-test.yml)

基于 [`padavanonly/immortalwrt-mt798x-24.10`](https://github.com/padavanonly/immortalwrt-mt798x-24.10) 的 `mt798x-mt799x-6.6-mtwifi` 分支，为 **Hiveton H5000M (MT7992 filogic)** 自动编译固件。

固件下载：[Releases](https://github.com/existyay/Auto-H5000M-BIN/releases)

| 项目 | 值 |
| --- | --- |
| 默认地址 | `192.168.6.1` / `immortalwrt.lan` |
| 用户名 | `root` |
| 密码 | `admin` |

---

## 仓库结构

```
.
├── .github/workflows/build-test.yml   # GitHub Actions 工作流 (调用 local-build.sh)
├── feeds.conf.default                 # OpenWrt feeds 配置
├── h5000m.extra.config              # 追加到 .config 的本机特定配置
├── patches/
│   └── mtwifi-apcli-active-only.patch # MTK WiFi AP/APCLI active-only 持久补丁
└── scripts/
    ├── local-build.sh                 # 本地/CI 共用的唯一构建入口
    ├── local-build.ps1               # Windows + WSL2 包装脚本
    └── coverage-test.sh              # 覆盖性配置测试
```

CI 与本地复用同一份 `scripts/local-build.sh`，不存在第二处脚本来源。

---

## 本地编译

### Windows + WSL2（推荐）

WSL2 是本地编译的推荐方式——原生 ext4 文件系统、无线程限制、ccache 持久化，相比 Docker 可节省数倍编译时间。

首次安装依赖：

```powershell
.\scripts\local-build.ps1 -InstallDeps
```

完整构建（默认会同步到 WSL 原生路径 `~/Auto-H5000M-BIN-localbuild`）：

```powershell
.\scripts\local-build.ps1
```

只跑准备/配置不编译：

```powershell
.\scripts\local-build.ps1 -ConfigOnly
.\scripts\local-build.ps1 -PrepareOnly
```

调整功能开关（任何 `ENABLE_*` 会被自动转发到 WSL bash）：

```powershell
$env:ENABLE_MOSDNS = 'false'
$env:ENABLE_QMODEM_NEXT = 'false'
.\scripts\local-build.ps1
```

全兼容插件本地编译示例（互斥项中选择 QModem Next，不同时启用旧 QModem/原版 Modem）：

```powershell
$env:ENABLE_ADGUARDHOME = 'true'
$env:ENABLE_OPENCLASH = 'true'
$env:ENABLE_NIKKI = 'true'
$env:ENABLE_UPNP = 'true'
$env:ENABLE_VLMCSD = 'true'
$env:ENABLE_MOSDNS = 'true'
$env:ENABLE_DOCKERMAN = 'true'
$env:ENABLE_QMODEM_NEXT = 'true'
$env:ENABLE_QMODEM = 'false'
$env:ENABLE_HOMEPROXY = 'true'
$env:ENABLE_ADBYBY_PLUS = 'true'
$env:ENABLE_ORIGINAL_MODEM = 'false'
$env:ENABLE_EASYMESH = 'true'
.\scripts\local-build.ps1
```

国内网络可按需覆盖下载镜像：

```powershell
$env:GOPROXY = 'https://goproxy.cn,https://proxy.golang.org,direct'
$env:GOSUMDB = 'sum.golang.google.cn'
$env:DOWNLOAD_MIRROR = 'https://mirrors.tuna.tsinghua.edu.cn/openwrt/sources;https://mirrors.ustc.edu.cn/openwrt/sources;https://mirrors.bfsu.edu.cn/openwrt/sources'
$env:GITHUB_PROXY_PREFIXES = 'https://ghfast.top/ https://gh-proxy.com/ https://gh.llkk.cc/'
```

### Linux / 直接在 WSL Shell 中

```bash
bash scripts/local-build.sh --install-deps   # 仅首次
ENABLE_MOSDNS=false THREADS=8 bash scripts/local-build.sh
```

只验证配置（快速迭代，不下载不编译）：

```bash
bash scripts/local-build.sh --config-only
SKIP_TOOLCHAIN=true SKIP_DOWNLOAD=true bash scripts/local-build.sh  # 最快迭代
```

覆盖性配置测试（不完整编译固件，只跑到补丁、feeds、defconfig 和关键包校验）：

```bash
bash scripts/coverage-test.sh quick
PROFILE_SET=full bash scripts/coverage-test.sh
FULL_BUILD_PROFILE=proxy-stack PROFILE_SET=quick bash scripts/coverage-test.sh
```

`quick` 覆盖默认构建和代理栈组合；`full` 会额外覆盖最小系统、HomeProxy-only、MosDNS-only、Nikki-only、旧 QModem、原版 modem、常用可选服务、全兼容插件和 DockerMan。`FULL_BUILD_PROFILE` 会在配置覆盖后额外完整编译一个指定 profile。

成功后产物在 `artifacts/`，并打包成 `artifacts.tar.gz`。

---

### 命令行选项

| PowerShell 开关 | bash 选项 | 说明 |
| --- | --- | --- |
| `-InstallDeps` | `--install-deps` | apt-get 安装编译依赖 |
| `-PrepareOnly` | `--prepare-only` | 拉源码 + feeds + 补丁后停止 |
| `-ConfigOnly` | `--config-only` | 上述 + defconfig 后停止 |
| `-SkipToolchain` | `--skip-toolchain` | 跳过显式 `make toolchain/install` |
| `-SkipDownload` | `--skip-download` | 跳过 `make download` |
| `-SkipFeedsUpdate` | `--skip-feeds-update` | 跳过 `./scripts/feeds update -a` (本地迭代提速) |

### 功能开关（环境变量）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `ENABLE_NIKKI` | `true` | Nikki / mihomo-meta 代理 |
| `ENABLE_UPNP` | `true` | UPnP IGD |
| `ENABLE_VLMCSD` | `true` | KMS 激活服务 |
| `ENABLE_MOSDNS` | `true` | MosDNS + v2ray-geodata |
| `ENABLE_QMODEM_NEXT` | `true` | QModem Next (新版 5G/LTE) |
| `ENABLE_ADGUARDHOME` | `false` | AdGuardHome |
| `ENABLE_OPENCLASH` | `false` | OpenClash |
| `ENABLE_DOCKERMAN` | `false` | DockerMan + dockerd |
| `ENABLE_QMODEM` | `false` | 旧版 QModem（与 `_NEXT` 互斥） |
| `ENABLE_HOMEPROXY` | `false` | HomeProxy |
| `ENABLE_ADBYBY_PLUS` | `false` | Adbyby Plus Lite |
| `ENABLE_ORIGINAL_MODEM` | `false` | 上游原版 modem（与 QModem 互斥） |
| `ENABLE_EASYMESH` | `true` | EasyMesh / 802.11s mesh 支持 |

### 下载优化变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `GOPROXY` | `https://goproxy.cn,https://proxy.golang.org,direct` | Go 模块代理，覆盖 MosDNS / Nikki / HomeProxy 的 Go 依赖下载 |
| `GOSUMDB` | `sum.golang.google.cn` | Go 校验数据库，避免 `sum.golang.org` 网络不可达 |
| `DOWNLOAD_MIRROR` | 清华/中科大/北外 OpenWrt sources | 传给 OpenWrt `scripts/download.pl` 的源码镜像列表 |
| `GITHUB_PROXY_PREFIXES` | `ghfast` / `gh-proxy` / `gh.llkk` | GitHub clone/raw 失败后的代理前缀回退，原始 URL 总是优先尝试 |
| `HOMEPROXY_REPO_URL` / `HOMEPROXY_REPO_BRANCH` | `immortalwrt/homeproxy` / `master` | HomeProxy 主源码 |
| `HOMEPROXY_FALLBACK_REPO_URL` / `HOMEPROXY_FALLBACK_REPO_BRANCH` | `VIKINGYFY/homeproxy` / `main` | HomeProxy 主源失败时的备用源码 |

---

## GitHub Actions

- 触发：每周日 16:00 UTC（北京时间周一 00:00）自动构建；亦可在 Actions 页面手动 `workflow_dispatch`。
- 手动触发时所有 `ENABLE_*` 与 `publish_release` 都是布尔输入；不勾选 `publish_release` 时只上传 Artifact，不创建 Release。
- 勾选 `publish_release` 时发布到固定 `latest` tag，并标记为 GitHub Latest Release；不会再作为 pre-release 发布。
- 手动触发时可勾选 `run_config_coverage`，并选择 `coverage_profile_set=quick/full`；需要固件级冒烟时填写 `full_build_smoke_profile`。
- coverage 配置测试与固件编译并行运行，不阻塞 Release 发布时间。
- feeds 更新失败会直接中止，避免在 GitHub Actions 中生成缺插件/缺依赖的固件。
- Artifact 内会包含 `build.config` 与 `enabled-packages.txt`，可直接确认 WiFi 补丁、MosDNS、HomeProxy、Nikki 等功能是否进入最终配置。

覆盖测试能显著降低回归风险，但不能证明固件"完全没有 bug"。无线环境、硬件状态、运营商网络、插件上游服务、运行时配置和客户端行为仍需要刷机后的真实设备验证。

---

## 持久修复要点

`patches/mtwifi-apcli-active-only.patch` 解决 MTK WiFi AP/APCLI 在禁用部分 VIF 时仍占用 BSSID 预算导致 AP 无法起来的问题：

- `mtwifi_cfg` 增加 `cfg_is_true` / `vif_is_enabled` / `sorted_vif_indices`；按启用 VIF 计算 `BssidNum` 并跳过 disabled VIF；
- `netifd/mtwifi.sh` 中 `mtwifi_vif_ap_set_data` / `mtwifi_vif_sta_set_data` 对 `disabled="1"` 早退；
- 应用方式：`local-build.sh` 在 `apply_package_fixes` 阶段对 `immortalwrt/` 执行幂等 forward / reverse dry-run；重复运行安全。

其它内嵌修复：QMI WWAN 驱动适配 Linux 6.6、v2dat Go 1.24 兼容、Go feed 强制 `sbwml/packages_lang_golang -b 24.x`、`mihomo-meta` 冲突剥离、`ebtables` 源镜像在匹配到 netfilter URL 时才替换。

插件源码修复：启用 Nikki 时会在 feed 更新失败/缺失后补拉 `nikkinikki-org/OpenWrt-nikki`，并校验 `nikki` / `mihomo-meta`；启用 OpenClash 时补拉 `vernesong/OpenClash` 内的 `luci-app-openclash`；启用 MosDNS 时补拉 `sbwml/luci-app-mosdns` 与 `sbwml/v2ray-geodata`，清理 feeds 内同名旧包，并校验 `mosdns` / `v2dat` / `v2ray-geoip` / `v2ray-geosite`；启用 HomeProxy 时补拉 `immortalwrt/homeproxy`，失败后回退到 `VIKINGYFY/homeproxy`，并强制校验 `luci-app-homeproxy` / `sing-box` / `kmod-nft-tproxy` 是否进入最终 `.config`。

UPnP 修复：`luci-app-upnp` 依赖虚拟包 `miniupnpd`，fw4 构建中显式选择 `miniupnpd-nftables` 与 `rpcd-mod-ucode`，避免 `defconfig` 将 `luci-app-upnp` 自动关闭。若上游源码引用 `libcrypt-compat` 但当前 feeds 未定义该包，构建脚本会补一个 glibc 条件下的兼容包定义，避免包扫描阶段刷屏 warning。

EasyMesh / mesh 支持：当前上游分支没有独立的 `luci-app-easymesh` 包；MTK EasyMesh/MAP 能力以内置 WiFi 驱动源码和 MT7992 `map_*.dat` profile 形式存在。`ENABLE_EASYMESH=true` 时脚本会启用 `mesh11sd` 与 `wpad-mesh-openssl`，替换基础 `wpad` 变体以保留 mesh 能力，并校验 MTK `feature/map` 源文件和 MT7992 MAP profile 是否仍在上游源码中。

---

## 许可证

继承上游 ImmortalWrt 项目许可证。
