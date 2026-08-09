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
| `ENABLE_MWAN3` | `false` | MWAN3 MultiWAN Manager（多 WAN 负载均衡/故障切换，含 LuCI 界面、kmod-vrf 及全部 kmod-ipt-* 内核依赖） |

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
- 运行器可在手动触发时选择：`github-hosted`（默认）或 `self-hosted`。选择 `self-hosted` 走你自己注册的 runner（详见下节），避免 free 账户被锁或分钟数不够时编译中断。

覆盖测试能显著降低回归风险，但不能证明固件“完全没有 bug”。无线环境、硬件状态、运营商网络、插件上游服务、运行时配置和客户端行为仍需要刷机后的真实设备验证。

---

## Self-hosted runner（free 账户被锁时仍能编译）

GitHub Actions 的免费额度（私有仓 2000 分钟/月）或 billing 锁定时，github-hosted runner 会被拒绝拉 job。本 workflow 支持 `runner_type=self-hosted` 走你自己的机器。

### 1. 在仓库上添加 runner

1. 进入仓库页面 → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. 选择 Linux x64，GitHub 会给出一段注册脚本。推荐同时勾选"Disable default runners on this repo"以外的额外能力。
3. 在 runner 标签处至少加：`linux`, `x64`, `h5000m`（默认值。如需加 GPU/快存机器也可自定义标签，运行时在 workflow_dispatch 的 `self_hosted_labels` 里填入）。

### 2. 准备 runner 环境

```bash
# Ubuntu 22.04/24.04 推荐。Runner 需要以下依赖（参考 local-build.sh “安装编译依赖”步骤）：
sudo apt-get update && sudo apt-get install -y --no-install-recommends \
  build-essential ccache python3 libncurses5-dev libssl-dev libgmp3-dev libmbedtls-dev \
  zlib1g-dev autoconf automake libtool patch gcc g++ gawk gettext unzip file wget curl \
  rsync zstd golang-go rustc cargo git ack antlr3 asciidoc binutils bison bzip2 clang cmake \
  cpio device-tree-compiler fastjar flex gcc-multilib g++-multilib gnutls-dev gperf haveged \
  help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
  libltdl-dev libmpc-dev libmpfr-dev libncursesw5-dev libpython3-dev libreadline-dev lld llvm \
  lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full pkgconf python3-pip python3-ply \
  python3-pyelftools python3-setuptools qemu-utils re2c scons squashfs-tools subversion swig \
  texinfo uglifyjs upx-ucl vim xmlto xxd

# 起码 30 GB 空闲磁盘（ccache 拉满可上 50 GB）。
# 编译时会创建 `work/_temp` 、调用 `chmod` 、`sudo` 不是必须的（自托管步骤已跳过 apt 安装）。
```

### 3. 启动 runner

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# （从 GitHub 页面拷贝的 ./config.sh --url ... --token ...）
./config.sh --labels linux,x64,h5000m
./svc.sh install && ./svc.sh start    # 作为 systemd 服务运行
```

### 4. 手动触发走 self-hosted

Actions → Run workflow → `runner_type` 选 `self-hosted`（默认 `linux,x64,h5000m` 标签）→ Run。任务会在你自己的 runner 上跑，不走 GitHub 额度。

### 5. 重要限制

- 如果 GitHub **org 整体**被锁定（例如未付款超过某些阈值），self-hosted runner 也可能拉不到 job——这种情况必须先在 https://github.com/settings/billing 解锁。
- self-hosted runner 必须是本 workflow 信任的机器。GitHub 仓库的设置默认要求组织所有者批准新 runner。
- 不要让 runner 以 root 运行（用普通用户 + sudo；脚本里 `apt-get` / 磁盘清理步骤会在 self-hosted 下自动跳过）。

---

## 持久修复要点

`patches/mtwifi-apcli-active-only.patch` 解决 MTK WiFi AP/APCLI 在禁用部分 VIF 时仍占用 BSSID 预算导致 AP 无法起来的问题：

- `mtwifi_cfg` 增加 `cfg_is_true` / `vif_is_enabled` / `sorted_vif_indices`；按启用 VIF 计算 `BssidNum` 并跳过 disabled VIF；
- `netifd/mtwifi.sh` 中 `mtwifi_vif_ap_set_data` / `mtwifi_vif_sta_set_data` 对 `disabled="1"` 早退；
- 应用方式：`local-build.sh` 在 `apply_package_fixes` 阶段对 `immortalwrt/` 执行幂等 forward / reverse dry-run；重复运行安全。

其它内嵌修复：QMI WWAN 驱动适配 Linux 6.6、v2dat Go 1.24 兼容、Go feed 强制 `sbwml/packages_lang_golang -b 24.x`、`mihomo-meta` 冲突剥离、`ebtables` 源镜像在匹配到 netfilter URL 时才替换。

插件源码修复：启用 Nikki 时会在 feed 更新失败/缺失后补拉 `nikkinikki-org/OpenWrt-nikki`，并校验 `nikki` / `mihomo-meta`；启用 OpenClash 时补拉 `vernesong/OpenClash` 内的 `luci-app-openclash`；启用 MosDNS 时补拉 `sbwml/luci-app-mosdns` 与 `sbwml/v2ray-geodata`，清理 feeds 内同名旧包，并校验 `mosdns` / `v2dat` / `v2ray-geoip` / `v2ray-geosite`；启用 HomeProxy 时补拉 `immortalwrt/homeproxy`，失败后回退到 `VIKINGYFY/homeproxy`，并强制校验 `luci-app-homeproxy` / `sing-box` / `kmod-nft-tproxy` 是否进入最终 `.config`。`luci-app-turboacc-mtk`（MTK HNAT / SFE / Shortcut-FE LuCI 面板）与 `luci-app-Airpifanctrl` 不在所用 feeds 中（immortalwrt 24.10 luci 与 immortalwrt-mt798x-24.10 上游分支都未携带），脚本会从 `hanwckf/immortalwrt-mt798x` 与 `padavanonly/immortalwrt-mt798x-6.6` 仓库拉取后拷贝到 `package/mtk/applications/` 下，并加上 verify 校验，避免 `.config` 静默丢失。

UPnP 修复：`luci-app-upnp` 依赖虚拟包 `miniupnpd`，fw4 构建中显式选择 `miniupnpd-nftables` 与 `rpcd-mod-ucode`，避免 `defconfig` 将 `luci-app-upnp` 自动关闭。若上游源码引用 `libcrypt-compat` 但当前 feeds 未定义该包，构建脚本会补一个 glibc 条件下的兼容包定义，避免包扫描阶段刷屏 warning。

EasyMesh / mesh 支持：上游 routing feed 的 `mesh11sd`（动态 802.11s mesh 配置守护进程）与 OpenWrt 内置 `wpad-mesh-openssl`（hostapd 变体）都可用；MTK MT7992 驱动源码含 `feature/map/map.c` 与 `map_mt7992.dbdc.{b0,b1}.dat` 等 MAP profile，`defconfig/mt7987_mt7992.config` 已经默认打开 `CONFIG_MTK_WIFI7_MAP_SUPPORT`。`ENABLE_EASYMESH=true` 时脚本会：

- 用 `mesh11sd` + `wpad-mesh-openssl` 替换基础 `wpad`（禁用所有 basic/mbedtls/wolfssl 变体，避免 hostapd 同源冲突）；
- 启用 MTK MT7992 MT7 的 MAP 套件：`MTK_WIFI7_MAP_SUPPORT`（R1）+ `MAP_R2..R6` + `MAP_VENDOR` + `MAP_HOSTAPD` + `MAP_R2/R3_6E`，让 MT7992.ko 编出完整 Multi-AP/EasyMesh 能力；
- 启用 `kmod-br-netfilter`（802.11s / EAPOL relay 依赖）；
- 校验 `mesh11sd` / `wpad-mesh-openssl` / `kmod-mt7992` / `kmod-mt799a` / `kmod-br-netfilter` / MTK `MTK_WIFI7_MAP_*` Kconfig 都进入 defconfig。

注意：上游 ImmortalWrt 24.10 luci feed **没有** `luci-app-mesh11sd` 包。mesh11sd 的 UCI 配置通过 SSH 手动修改 `/etc/config/mesh11sd`，或下载第三方面板插件管理。

MWAN3 多 WAN 支持：`ENABLE_MWAN3=true` 会同时启用 `mwan3` 后台、`luci-app-mwan3` 与中文包、`kmod-vrf`（同时设置 `CONFIG_KERNEL_NET_L3_MASTER_DEV=y` 解锁该内核符号，修复 LuCI 添加设备时提示需要 `kmod-vrf` 的问题），以及 `kmod-ipt-ipset` / `kmod-ipt-conntrack-extra` / `kmod-ipt-ipopt` / `kmod-ipt-raw` / `kmod-nf-conncount` 等内核模块和 `iptables-mod-conntrack-extra` / `iptables-mod-ipopt` / `ipset` 等用户态组件。这能避免运行时用 opkg 安装 `luci-app-mwan3` 时反复报 "依赖的软件包 kmod-ipt-* 在所有仓库都未提供"。所有 kmod 都在 image 构建时打入，不需要刷机后手动装。

IPv6 基础设施：上游 `mt7987_mt7992.config` 默认开启了 `IPV6=y` 但保留 IPv6 netfilter 链路（kmod-ip6tables / kmod-ipt-nat6 / libip6tc / ip6tables-extra 等）全部 `is not set`。本项目同时启用 mwan3（v2.11.16 在 IPV6 模式会创建带 `-p ipv6-icmp --icmpv6-type 133/134/135/136/137` 的 mwan3_hook 链）和多代组件（Nikki / HomeProxy / MosDNS），若不补齐 IPv6 netfilter 栈，运行时会拿到 `can't initialize iptables table 'filter'+ 模块缺失` 以及 mwan3 IPv6 路径静默不生效。`h5000m.extra.config` 默认补齐 `kmod-nf-ipt6` / `kmod-ip6tables` / `kmod-ip6tables-extra` / `kmod-ipt-nat6` / `kmod-nf-nat6` / `kmod-ip6-tunnel` / `libip6tc` / `ip6tables-mod-nat` / `ip6tables-extra` / `ip6tables-nft` / `ip6tables-zz-legacy`，使 LAN/WAN IPv6 RA+DHCPv6、NDP、IPv6 NAT、fw4 IPv6 转发均能工作。

MTK HNAT / 网络加速：MT798x 默认启用 `kmod-mediatek_hnat`（硬件 NAT offload），`mtk_hnat_nf_hook` 在 `NF_INET_PRE_ROUTING @ NF_IP_PRI_MANGLE-1` 与 `NF_INET_PRE_ROUTING @ NF_IP_PRI_FIRST+1` 等多个优先级点向 netfilter 注册 hook，在命中硬件流表时调用 `dev_queue_xmit` 直接转发，避免 fw4 / nftables 介入。这意味着：

- **从 LAN（插线）访问路由器后台**（192.168.6.1）：包被识别为本地 INPUT，HNAT hook 返回 NF_ACCEPT，流走 INPUT 链。正常工作。
- **从 WiFi 客户端访问路由器后台**（192.168.6.1）：如果 HNAT 已为该流（5 元组）生成过 hardware shortcut，第二次 SYN 会被 `do_hnat_ge_to_ext()` → `dev_queue_xmit()` 直接转走，跳过 INPUT 链。表现是 `curl http://192.168.6.1/` 超时/拒接、浏览器白页。

`luci-app-turboacc-mtk` 面板中的"软件流卸载" / "HNAT"开关实际控制 UCI 选项转 sysfs 写入（`/sys/kernel/debug/hnat/`）。遇到上述现象时：在路由器后台 → 网络 → Turbo ACC → 取消启用 **Software flow offloading**（Shortcut-FE）和 **Hardware NAT**、点击 "Apply" 即可恢复。运行 `echo 0 > /sys/kernel/debug/hnat/hooks` 可以临时挂起 HNAT hook，不用重启服务。

---

## 许可证

继承上游 ImmortalWrt 项目许可证。
