#Requires -Version 5.1
<#
   鸣潮 XXMI + ReShade + DLSS5 一键部署
   前置：已安装游戏（DX11 可启动）与 XXMI Launcher（WWMI 已配置好 Mods）
   原理：用 Ultimate-ASI-Loader 按 global.ini 的顺序加载 d3d11.asi(3DMigoto) 与 ReShade.asi，
        3DMigoto 先占 D3D11，ReShade 后包在外层，NVIDIA AI 插帧挂最外，实现 mod 与插帧共存。
#>
param(
    [string]$GameDir,   # 游戏 Win64 目录，可选。不给则自动查找
    [string]$WwmiDir    # XXMI 的 WWMI 目录，可选。不给则自动查找
)

$ErrorActionPreference = "Stop"
$root         = Split-Path -Parent $MyInvocation.MyCommand.Path
$filesBin     = Join-Path $root "files\bin"
$filesScripts = Join-Path $root "files\scripts"

function Say($m, $c = "Gray") { Write-Host $m -ForegroundColor $c }
function Step($m) { Say ""; Say "==> $m" Cyan }
function Ok($m)   { Say "    [OK] $m" Green }
function Note($m) { Say "    [!!] $m" Yellow }

function Test-Win64($p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    return (Test-Path (Join-Path $p "Client-Win64-Shipping.exe"))
}
function Test-Wwmi($p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    return ((Test-Path (Join-Path $p "d3d11.dll")) -and (Test-Path (Join-Path $p "Mods")))
}

function Find-GameDir {
    $cfgList = @()
    if ($env:APPDATA) { $cfgList += (Join-Path $env:APPDATA "XXMI Launcher\XXMI Launcher Config.json") }
    foreach ($d in @("D:\mod\XXMI Launcher", "C:\mod\XXMI Launcher", "D:\XXMI Launcher", "C:\XXMI Launcher")) {
        $cfgList += (Join-Path $d "XXMI Launcher Config.json")
    }
    foreach ($f in $cfgList) {
        if (-not (Test-Path $f)) { continue }
        $m = Select-String -Path $f -Pattern '"game_folder"\s*:\s*"([^"]+)"' | Select-Object -First 1
        if ($m) {
            $gf = ($m.Matches[0].Groups[1].Value) -replace '\\\\', '\'
            if ([string]::IsNullOrWhiteSpace($gf)) { continue }
            foreach ($cand in @((Join-Path $gf "Client\Binaries\Win64"), $gf)) {
                if (Test-Win64 $cand) { return $cand }
            }
        }
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root)) {
        foreach ($rel in @(
                "Wuthering Waves\Wuthering Waves Game\Client\Binaries\Win64",
                "Wuthering Waves Game\Client\Binaries\Win64",
                "Games\Wuthering Waves\Wuthering Waves Game\Client\Binaries\Win64")) {
            $cand = Join-Path $d $rel
            if (Test-Win64 $cand) { return $cand }
        }
    }
    return $null
}

function Find-WwmiDir {
    $cands = @()
    if ($env:APPDATA) { $cands += (Join-Path $env:APPDATA "XXMI Launcher\WWMI") }
    $cands += @("D:\mod\XXMI Launcher\WWMI", "C:\mod\XXMI Launcher\WWMI",
                "D:\XXMI Launcher\WWMI", "C:\XXMI Launcher\WWMI",
                (Join-Path (Split-Path $root -Parent) "WWMI"))
    foreach ($p in $cands) { if (Test-Wwmi $p) { return $p } }
    # 退而求其次：在常见盘符下找 XXMI Launcher\WWMI
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root)) {
        $p = Join-Path $d "mod\XXMI Launcher\WWMI"
        if (Test-Wwmi $p) { return $p }
    }
    return $null
}

function Remove-JunctionSafe($path) {
    if (-not (Test-Path $path)) { return }
    $it = Get-Item $path -Force
    if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        & cmd /c "rmdir `"$path`"" | Out-Null   # 只删链接点，不动目标
    } else {
        Remove-Item $path -Recurse -Force
    }
}

function Deploy-File($src, $dst) {
    if (Test-Path $dst) { Remove-Item $dst -Force }
    try {
        New-Item -ItemType HardLink -Path $dst -Target $src | Out-Null
        return "硬链接"
    } catch {
        Copy-Item $src $dst -Force
        return "复制"
    }
}

# ---------- 1. 定位目录 ----------
Step "定位目录"
if (-not (Test-Win64 $GameDir)) { $GameDir = Find-GameDir }
if (-not (Test-Win64 $GameDir)) {
    Say "    没找到游戏目录，请手动输入（也可把文件夹拖进来后回车）：" Yellow
    $in = (Read-Host "    游戏 Win64 目录").Trim('"')
    if (Test-Win64 $in) { $GameDir = $in } else { Say "    路径无效：$in" Red; exit 1 }
}
Ok "游戏目录：$GameDir"

if (-not (Test-Wwmi $WwmiDir)) { $WwmiDir = Find-WwmiDir }
if (-not (Test-Wwmi $WwmiDir)) {
    Say "    没找到 WWMI 目录，请手动输入：" Yellow
    $in = (Read-Host "    WWMI 目录").Trim('"')
    if (Test-Wwmi $in) { $WwmiDir = $in } else { Say "    路径无效：$in" Red; exit 1 }
}
Ok "WWMI 目录：$WwmiDir"

foreach ($f in @($filesBin, $filesScripts)) {
    if (-not (Test-Path $f)) { Say "    部署包缺少文件：$f" Red; exit 1 }
}

# ---------- 2. 清理旧部署 ----------
Step "清理旧部署"
foreach ($n in @("d3d11.dll", "dxgi.dll", "nvngx_dlss.dll", "nvngx_dlssnr.dll")) {
    $p = Join-Path $GameDir $n
    if (Test-Path $p) { Remove-Item $p -Force; Ok "已移除 $n" }
}
$scriptsDir = Join-Path $GameDir "scripts"
if (Test-Path $scriptsDir) {
    Get-ChildItem $scriptsDir -Force | Where-Object {
        $_.Attributes -band [IO.FileAttributes]::ReparsePoint
    } | ForEach-Object { Remove-JunctionSafe $_.FullName }
    Remove-Item $scriptsDir -Recurse -Force
    Ok "已移除旧 scripts"
}

# ---------- 3. 部署 scripts ----------
Step "部署 scripts（ReShade + 插件）"
Copy-Item $filesScripts (Join-Path $GameDir "scripts") -Recurse -Force
$scriptsDir = Join-Path $GameDir "scripts"
Ok "脚本与插件已就位"

Step "接入 XXMI（WWMI）"
$linkFiles = @{
    "d3d11.asi"           = "d3d11.dll"
    "d3dx.ini"            = "d3dx.ini"
    "d3dx_user.ini"       = "d3dx_user.ini"
    "d3dcompiler_47.dll"  = "d3dcompiler_47.dll"
}
foreach ($k in $linkFiles.Keys) {
    $src = Join-Path $WwmiDir $linkFiles[$k]
    if (Test-Path $src) {
        $how = Deploy-File $src (Join-Path $scriptsDir $k)
        Ok "$k <- $($linkFiles[$k])（$how）"
    }
}
foreach ($d in @("Mods", "Core", "ShaderFixes", "ShaderCache", "Screenshots", "qaqm")) {
    $src = Join-Path $WwmiDir $d
    if (Test-Path $src) {
        $dst = Join-Path $scriptsDir $d
        Remove-JunctionSafe $dst
        New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        Ok "$d（目录联接）"
    }
}

# ---------- 4. 部署加载器与运行时 ----------
# 注意：这里绝不能部署 d3d11.dll。3DMigoto 已由 ASI Loader 以 scripts\d3d11.asi 加载，
# 若系统目录下再放一份 d3d11.dll，会产生两份 3DMigoto 互相挂钩，进程递归死锁后崩溃 (0xc0000005)。
Step "部署加载器与 DLSS 运行时"
foreach ($n in @("dxgi.dll", "nvngx_dlss.dll", "nvngx_dlssnr.dll")) {
    $how = Deploy-File (Join-Path $filesBin $n) (Join-Path $GameDir $n)
    Ok "$n（$how）"
}

# ---------- 5. 完成 ----------
Step "完成"
Say @"

    已部署到：$GameDir

    启动方式（重要）：
      用库洛官方启动器 / WeGame 启动，游戏内图形设置选 DirectX 11。
      不要用 XXMI Launcher 点启动 —— 它会覆盖 d3d11.dll，破坏加载链。

    验证：
      1) 进游戏看画面左上角 3DMigoto 绿色字体（mod 生效）
      2) 按 Home 打开 ReShade，能看到 RenoDX / DLSS5 面板
      3) 英伟达 App 的 AI 插帧保持开启即可共存

    需要恢复原状：运行 一键卸载.bat

"@ Cyan
