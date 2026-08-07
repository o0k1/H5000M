param(
    [switch]$InstallDeps,
    [switch]$PrepareOnly,
    [switch]$ConfigOnly,
    [switch]$SkipToolchain,
    [switch]$SkipDownload,
    [switch]$SkipFeedsUpdate,
    [switch]$UseMountedWorkspace,
    [string]$WslWorkDir = '~/Auto-H5000M-BIN-localbuild',
    [string]$Distro
)

# 在 Windows + WSL2 下运行 scripts/local-build.sh 的包装脚本。
# 默认会把当前仓库 rsync 到 WSL 原生路径 (~/Auto-H5000M-BIN-localbuild)，
# 满足 OpenWrt 对大小写敏感文件系统的要求。
#
# 通过 -UseMountedWorkspace 可直接在 /mnt/<drive>/... 上构建 (不推荐，速度慢)。
#
# 所有 ENABLE_* / THREADS / GOPROXY / GOSUMDB / DOWNLOAD_MIRROR / REPO_* / CONFIG_URL 等环境变量会自动从
# 当前 PowerShell 会话转发给 WSL bash，例如：
#   $env:ENABLE_MOSDNS = 'false'
#   .\scripts\local-build.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    throw 'wsl.exe was not found. Install WSL2 with Ubuntu, or run scripts/local-build.sh on a Linux host.'
}

function Set-DefaultEnv {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$Value)
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name, 'Process'))) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
}

# Set defaults for build environment variables
if ($Threads -le 0) {
    $Threads = [Math]::Max(2, [Environment]::ProcessorCount)
}
Set-DefaultEnv 'THREADS' $Threads.ToString()
Set-DefaultEnv 'FORCE' '1'
Set-DefaultEnv 'MAKEFLAGS' "-j$Threads"
Set-DefaultEnv 'GOPROXY' 'https://goproxy.cn,https://proxy.golang.org,direct'
Set-DefaultEnv 'GOSUMDB' 'sum.golang.google.cn'
Set-DefaultEnv 'DOWNLOAD_MIRROR' 'https://mirrors.tuna.tsinghua.edu.cn/openwrt/sources;https://mirrors.ustc.edu.cn/openwrt/sources;https://mirrors.bfsu.edu.cn/openwrt/sources'
Set-DefaultEnv 'GITHUB_PROXY_PREFIXES' 'https://ghfast.top/ https://gh-proxy.com/ https://gh.llkk.cc/'

function ConvertTo-WslPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ($resolved -notmatch '^([A-Za-z]):[\\/](.*)$') {
        throw "Only drive-letter Windows paths are supported: $resolved"
    }
    $drive = $matches[1].ToLowerInvariant()
    $rest = $matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

function ConvertTo-BashQuoted {
    param([Parameter(Mandatory = $true)][string]$Value)
    $escaped = $Value.Replace("'", "'\''")
    return "'" + $escaped + "'"
}

$wslArgs = @()
if ($Distro) { $wslArgs += @('-d', $Distro) }

$linuxRoot = ConvertTo-WslPath -Path $repoRoot

$scriptArgs = @()
if ($InstallDeps)     { $scriptArgs += '--install-deps' }
if ($PrepareOnly)     { $scriptArgs += '--prepare-only' }
if ($ConfigOnly)      { $scriptArgs += '--config-only' }
if ($SkipToolchain)   { $scriptArgs += '--skip-toolchain' }
if ($SkipDownload)    { $scriptArgs += '--skip-download' }
if ($SkipFeedsUpdate) { $scriptArgs += '--skip-feeds-update' }

$forwardedNames = @(
    'ENABLE_ADGUARDHOME','ENABLE_OPENCLASH','ENABLE_NIKKI','ENABLE_UPNP','ENABLE_VLMCSD',
    'ENABLE_MOSDNS','ENABLE_DOCKERMAN','ENABLE_QMODEM_NEXT','ENABLE_QMODEM',
    'ENABLE_HOMEPROXY','ENABLE_ADBYBY_PLUS','ENABLE_ORIGINAL_MODEM','ENABLE_EASYMESH',
    'THREADS','FORCE','MAKEFLAGS','CCACHE_DIR','CCACHE_SIZE',
    'GOPROXY','GOSUMDB','DOWNLOAD_MIRROR','GITHUB_PROXY_PREFIXES',
    'HOMEPROXY_REPO_URL','HOMEPROXY_REPO_BRANCH','HOMEPROXY_FALLBACK_REPO_URL','HOMEPROXY_FALLBACK_REPO_BRANCH',
    'REPO_URL','REPO_BRANCH','CONFIG_URL','SOURCE_DIR','ARTIFACTS_DIR'
)
$exportLines = @()
foreach ($name in $forwardedNames) {
    $val = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ($null -ne $val -and $val -ne '') {
        $exportLines += ('export {0}={1}' -f $name, (ConvertTo-BashQuoted $val))
    }
}

if ($UseMountedWorkspace) {
    $wrapperLines = @('set -e') + $exportLines + @(
        ('cd {0}' -f (ConvertTo-BashQuoted $linuxRoot)),
        'exec bash scripts/local-build.sh "$@"'
    )
    Write-Host "Running local build in mounted WSL path: $linuxRoot"
} else {
    $effectiveWslWorkDir = $WslWorkDir
    # Expand ~ to WSL home for paths starting with ~/
    if ($effectiveWslWorkDir.StartsWith('~/')) {
        $wslHome = (& $wsl.Source @wslArgs bash -lc 'printf %s "$HOME"').Trim()
        if ($wslHome) {
            $effectiveWslWorkDir = $wslHome.TrimEnd('/') + '/' + $effectiveWslWorkDir.Substring(2)
        }
    }
    # Sanitize: reject empty or absolute Windows paths
    if ([string]::IsNullOrWhiteSpace($effectiveWslWorkDir) -or $effectiveWslWorkDir -match '^[A-Za-z]:') {
        throw "WslWorkDir must be a relative Linux path (e.g. ~/build or ./build): received '$effectiveWslWorkDir'"
    }
    $wrapperLines = @('set -e') + $exportLines + @(
        ('src={0}' -f (ConvertTo-BashQuoted $linuxRoot)),
        ('dst={0}' -f (ConvertTo-BashQuoted $effectiveWslWorkDir)),
        'mkdir -p "$dst"',
        'if command -v rsync >/dev/null 2>&1; then',
        '  rsync -a --delete --exclude "/.git" --exclude "/immortalwrt" --exclude "/artifacts" --exclude "/artifacts.tar.gz" --exclude "/source.tar.gz" "$src"/ "$dst"/',
        'else',
        '  rm -rf "$dst"',
        '  mkdir -p "$dst"',
        '  cp -a "$src"/. "$dst"/',
        '  rm -rf "$dst/.git" "$dst/immortalwrt" "$dst/artifacts" "$dst/artifacts.tar.gz" "$dst/source.tar.gz"',
        'fi',
        'cd "$dst"',
        'set +e',
        'bash scripts/local-build.sh "$@"',
        'status=$?',
        'set -e',
        'if [ "$status" -eq 0 ] && [ -d "$dst/artifacts" ]; then',
        '  rm -rf "$src/artifacts" "$src/artifacts.tar.gz"',
        '  if command -v rsync >/dev/null 2>&1; then',
        '    mkdir -p "$src/artifacts"',
        '    rsync -a --delete "$dst/artifacts"/ "$src/artifacts"/',
        '  else',
        '    cp -a "$dst/artifacts" "$src/artifacts"',
        '  fi',
        '  [ -f "$dst/artifacts.tar.gz" ] && cp -f "$dst/artifacts.tar.gz" "$src/artifacts.tar.gz"',
        'fi',
        'exit "$status"'
    )
    Write-Host "Syncing repository to WSL native path: $effectiveWslWorkDir"
}

$wrapperContent = ($wrapperLines -join "`n") + "`n"
$wrapperPath = Join-Path ([System.IO.Path]::GetTempPath()) ("auto-h5000m-local-build-{0}.sh" -f $PID)
[System.IO.File]::WriteAllText($wrapperPath, $wrapperContent, [System.Text.UTF8Encoding]::new($false))
$linuxWrapperPath = ConvertTo-WslPath -Path $wrapperPath
try {
    & $wsl.Source @wslArgs -u root bash $linuxWrapperPath @scriptArgs
    exit $LASTEXITCODE
}
finally {
    Remove-Item -LiteralPath $wrapperPath -Force -ErrorAction SilentlyContinue
}
