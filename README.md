# 鸣潮 XXMI + ReShade + DLSS5 一键部署包

[![Release](https://img.shields.io/github/v/release/aiertana/wwmi-dlss5-kit?style=flat-square)](https://github.com/aiertana/wwmi-dlss5-kit/releases/latest)

## 下载

到 [Releases](https://github.com/aiertana/wwmi-dlss5-kit/releases/latest) 下载 `WWMI-DLSS5-Deploy.zip`（约 143 MB）并解压，里面 bat 和 exe 两种入口都有。

在**已安装鸣潮**和**已配置好 WWMI 的 XXMI Launcher**基础上，一键部署
「3DMigoto(mod) + ReShade + DLSS5 神经渲染 + NVIDIA AI 插帧共存」的运行环境。

## 它解决什么

- XXMI 的 3DMigoto 与 NVIDIA App 的 AI 插帧抢 D3D11 钩子，开了插帧 mod 就注入失败
- ReShade 6.8.0 直接以 `dxgi.dll` 安装时闪退
- 想在 DX11 下用上 DLSS5 神经渲染超分

原理是用 **Ultimate-ASI-Loader** 按固定顺序加载插件：

```
d3d11.asi   3DMigoto（XXMI 的 mod 引擎）   ← 先占住 D3D11
ReShade.asi ReShade 6.8.0（含 RenoDX/DLSS5 插件） ← 包在外层
AI 插帧（NVIDIA）挂在最外层
```

顺序写在 `files\scripts\global.ini`：`LoadOrder=d3d11.asi,ReShade.asi`

## 前置条件

1. 鸣潮本体（能用 DX11 启动）
2. [XXMI Launcher](https://github.com/SpectrumQT/XXMI-Launcher) 已装好，WWMI 的 `Mods` 里已有你的 mod
3. Windows 10/11 x64，游戏目录与 XXMI 在同一块盘（不在同一盘也能装，会自动退化为复制）

## 用法

1. 解压本包
2. 双击 **`一键部署.bat`**
3. 脚本会自动找游戏目录和 WWMI 目录（从 `XXMI Launcher Config.json` 读），找不到会让你手动填
4. 部署完成后，**用库洛官方启动器 / WeGame 启动游戏**，游戏内图形设置选 **DirectX 11**

> ⚠️ **不要用 XXMI Launcher 点启动**：它会把自己那份 `d3d11.dll` 铺进游戏目录，顶掉 ASI 加载器，整条链子会断。
> XXMI Launcher 仍可用来管理和更新 mod，只是别用它启动游戏。

## 验证

| 检查项 | 现象 |
|---|---|
| mod 生效 | 进游戏后画面左上角有 **3DMigoto 绿色字体** |
| ReShade 生效 | 按 **Home** 打开面板，能看到 RenoDX / DLSS5 页签 |
| DLSS5 超分 | 游戏设置里打开 DLSS，RenoDX 面板不再显示「等待 D3D12 工具」 |
| AI 插帧共存 | 英伟达 App 的 AI 插帧保持开启即可 |

## 卸载

双击 **`一键卸载.bat`**，会删除游戏目录里的 `d3d11.dll`、`dxgi.dll`、`nvngx_dlss*.dll`、`scripts`，
恢复纯净状态。**不会动你的 WWMI 目录和 Mods**。

## 目录结构

```
一键部署.bat          入口
一键卸载.bat
install.ps1           部署脚本（自动定位路径、建硬链接/目录联接）
uninstall.ps1         卸载脚本（安全解除联接，不误删 Mods）
files\
  bin\                放到游戏目录
    d3d11.dll         Ultimate-ASI-Loader 9.7.4
    dxgi.dll          ASI Loader（dxgi 变体）
    nvngx_dlss.dll    DLSS 超分运行时
    nvngx_dlssnr.dll  DLSS5 神经渲染运行时
  scripts\            ASI Loader 的插件目录
    ReShade.asi       ReShade 6.8.0
    ReShade.ini       含 [RenoDX.DLSS5] DX11Source=native
    global.ini        LoadOrder=d3d11.asi,ReShade.asi
    renodx-dlss5-v10.5.0.addon64
    dlss5-feed.addon64
    ReshadeEffectShaderToggler.addon64 + .ini   防 ReShade UI 被覆盖
```

部署后游戏目录会变成：

```
Client\Binaries\Win64\
  d3d11.dll  dxgi.dll  nvngx_dlss.dll  nvngx_dlssnr.dll
  scripts\
    d3d11.asi → 硬链接 XXMI\WWMI\d3d11.dll
    d3dx.ini / d3dcompiler_47.dll → 硬链接
    Mods / Core / ShaderFixes / ShaderCache → 目录联接
    ReShade.asi + 插件
```

用硬链接和目录联接，所以 **XXMI 里加删 mod 立刻生效**，不用重装。
但如果 **XXMI 更新了 3DMigoto 本体**（`d3d11.dll` 被替换），重跑一次 `一键部署.bat` 即可。

## 常见问题

**ReShade 面板显示「NR 正在等待 D3D12 工具」**
插件默认 `DX11Source=foreign`（等第三方 D3D12 桥）。本包已设为 `native`（服务游戏自身的 DLSS）。
若你自己改过配置，检查 `scripts\ReShade.ini` 的 `[RenoDX.DLSS5]` 里有 `DX11Source=native`。
注意：改配置要在**游戏关闭时**改，否则退出游戏时会被内存中的配置覆盖回去。

**进游戏没有绿色字体**
先在 DX11 下用 XXMI Launcher 原版方式确认 mod 本身能加载；确认后再用本包方式启动。

**RenoDX 面板想换回中文**
把 `files\scripts\renodx-dlss5-v10.5.0.addon64` 换成汉化版（如 4.7 汉化），
插件文件名可以任意，ReShade 只认 `.addon64` 后缀。

**日志在哪**
`Client\Binaries\Win64\scripts\ReShade.log`，报问题时一并提交。

## 组件来源

| 组件 | 源链接 |
|---|---|
| XXMI Launcher | https://github.com/SpectrumQT/XXMI-Launcher |
| Ultimate-ASI-Loader | https://github.com/ThirteenAG/Ultimate-ASI-Loader |
| ReShade | https://reshade.me |
| HardLinkShellExt（原教程用） | https://schinagl.priv.at/nt/hardlinkshellext/hardlinkshellext.html |

## 许可

本包只做文件归集与部署自动化，各组件遵循其各自许可证。
第三方 DLL 与 add-on 版权归原作者所有。
