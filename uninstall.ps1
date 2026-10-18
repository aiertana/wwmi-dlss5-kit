#Requires -Version 5.1
<#
   卸载：把一键部署写入游戏目录的文件全部移除，恢复纯净状态。
   注意：只删除链接与本包部署的文件，不会动 WWMI 目录里的 Mods。
#>
param(
    [string]$GameDir
)

$ErrorActionPreference = "Stop"

function Say($m, $c = "Gray") { Write-Host $m -ForegroundColor $c }
function Step($m) { Say ""; Say "==> $m" Cyan }
function Ok($m)   { Say "    [OK] $m" Green }
function Note($m) { Say "    [!!] $m" Yellow }

function Test-Win64($p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    return (Test-Path (Join-Path $p "Client-Win64-Shipping.exe"))
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
                "Wuthering Waves Game\Client\Binaries\Win64")) {
            $cand = Join-Path $d $rel
            if (Test-Win64 $cand) { return $cand }
        }
    }
    return $null
}

Step "定位游戏目录"
if (-not (Test-Win64 $GameDir)) { $GameDir = Find-GameDir }
if (-not (Test-Win64 $GameDir)) {
    $in = (Read-Host "    没找到游戏目录，请手动输入 Win64 路径").Trim('"')
    if (Test-Win64 $in) { $GameDir = $in } else { Say "    路径无效" Red; exit 1 }
}
Ok "游戏目录：$GameDir"

Step "移除部署的文件"
foreach ($n in @("d3d11.dll", "dxgi.dll", "nvngx_dlss.dll", "nvngx_dlssnr.dll")) {
    $p = Join-Path $GameDir $n
    if (Test-Path $p) { Remove-Item $p -Force; Ok "已删除 $n" } else { Note "未发现 $n（跳过）" }
}

$scriptsDir = Join-Path $GameDir "scripts"
if (Test-Path $scriptsDir) {
    # 先删目录联接，避免递归时误删源目录里的 Mods
    Get-ChildItem $scriptsDir -Force | Where-Object {
        $_.Attributes -band [IO.FileAttributes]::ReparsePoint
    } | ForEach-Object {
        & cmd /c "rmdir `"$($_.FullName)`"" | Out-Null
        Ok "已解除联接 $($_.Name)"
    }
    Remove-Item $scriptsDir -Recurse -Force
    Ok "已删除 scripts"
} else {
    Note "未发现 scripts（跳过）"
}

Step "完成"
Say @"

    已恢复纯净状态，WWMI 目录与 Mods 未受影响。
    之后可以直接用 XXMI Launcher 启动（DX11 原版方式）。

"@ Cyan
