# CONTEXT.md — 项目接手文档

> **给另一个工作区/另一个 AI 读的。** 读完这份文档即可完整接手本项目，不需要翻历史对话。
> 最后更新：2026-10-22

## 0. 一句话

一个把「鸣潮 XXMI 的 3DMigoto mods + ReShade 6.8 + RenoDX DLSS5 神经渲染 + NVIDIA AI 插帧」串成一条加载链、实现共存的一键部署包。

- 项目根目录：`D:\mod\WWMI-DLSS5-Deploy`
- 仓库：https://github.com/aiertana/wwmi-dlss5-kit
- 游戏目录：`D:\Wuthering Waves\Wuthering Waves Game\Client\Binaries\Win64`（下称 `<Win64>`）
- XXMI：`D:\mod\XXMI Launcher\WWMI`（下称 `<WWMI>`）

---

## 1. 解决什么问题

| 问题 | 说明 |
|---|---|
| mod 与插帧互斥 | XXMI 的 3DMigoto 和 NVIDIA App 的 AI 插帧抢 D3D11 钩子，开了插帧 mod 就注入失败 |
| ReShade 直装闪退 | ReShade 6.8 以 `dxgi.dll` 直接安装会闪退 |
| DLSS5 神经渲染 | 想在 DX11 下用上 DLSS5 |

核心思路：**用 Ultimate-ASI-Loader 统一调度**，让 3DMigoto 先占住 D3D11，ReShade 包在外层，插帧挂最外。

---

## 2. 加载链（★ 全项目最重要的一张图）

```
Client-Win64-Shipping.exe
│
├─ 加载 <Win64>\dxgi.dll      146 KB   薄壳，仅把 dxgi 调用转发给 d3d11.dll
│
└─ 加载 <Win64>\d3d11.dll     3.6 MB   ★ Ultimate-ASI-Loader 9.7.4 —— 加载器本体
     │                                    （由 files\bin\d3d11.dll 部署，时间戳 2026/8/16）
     └─ 按 <Win64>\scripts\global.ini 的顺序加载插件：
          [Plugins]
          LoadOrder=d3d11.asi,ReShade.asi
          │
          ├─ scripts\d3d11.asi      3.19 MB  XXMI 3DMigoto 1.2.2  → 承载 Mods
          │                                 （install 时硬链接自 <WWMI>\d3d11.dll）
          │
          └─ scripts\ReShade.asi    5.6 MB   ReShade 6.8.0.2155
               └─ 自动扫描同目录 *.addon64：
                    ├─ renodx-dlss5-v10.5.0.addon64   RenoDX DLSS5 神经渲染
                    ├─ dlss5-feed.addon64             DLSS5 Feed
                    └─ ReshadeEffectShaderToggler.addon64  着色器开关
```

关键：**3DMigoto 只有一份，以 `d3d11.asi` 形式由加载器载入**，不存在"两份 3DMigoto 重复注入"。

---

## 3. 文件身份对照表（★ 极易搞混，改文件前先查这里）

| 文件 | 大小/日期 | 真实身份 | 能不能动 |
|---|---|---|---|
| `<Win64>\d3d11.dll` | 3.6 MB / 8-16 | **Ultimate ASI Loader 9.7.4**（加载器） | **绝不能删、不能被覆盖**。删了 `scripts` 里所有插件都不会加载，全部功能失效 |
| `<Win64>\dxgi.dll` | 146 KB / 8-31 | 薄壳 wrapper，只转发 `D3D11CreateDevice` | 保留，别换成 ReShade 的 dxgi |
| `<Win64>\scripts\d3d11.asi` | 3.19 MB / 10-6 | **XXMI 3DMigoto 1.2.2**（mod 引擎） | 与 `<WWMI>\d3d11.dll` 是同一个文件（硬链接） |
| `<WWMI>\d3d11.dll` | 3.19 MB / 10-6 | 3DMigoto 本体（XXMI 自带的） | 不要动，项目从这里硬链接 |
| `<WWMI>\dxgi.dll` | 5.2 MB / 2025-12-29 | XXMI 自带的 ReShade 6.6.1 | 本项目不用它，留在 XXMI 目录不动 |
| `<Win64>\nvngx_dlss.dll` | 56 MB | 游戏自带 DLSS 运行时 | **别删**，删了游戏内 DLSS 挂掉 |
| `<Win64>\nvngx_dlssnr.dll` | 158 MB | DLSS 神经渲染库 | **别删** |

> ⚠️ 两个 `d3d11.dll` 名字相同但**内容完全不同**：`<Win64>` 那份是 ASI Loader，`<WWMI>` 那份是 3DMigoto。曾误判为"重复注入"并删掉游戏目录那份，导致整套功能失效，已恢复。

---

## 4. 项目文件结构

```
WWMI-DLSS5-Deploy/
├─ install.ps1              部署脚本（自动定位游戏目录与 WWMI，硬链接+目录联接）
├─ uninstall.ps1            卸载还原
├─ 一键部署.bat / 一键卸载.bat   bat 入口（内部 powershell -ExecutionPolicy Bypass）
├─ README.md                面向用户的说明
├─ CONTEXT.md               本文件
├─ files/
│   ├─ bin/                 部署到游戏根目录
│   │   ├─ d3d11.dll        Ultimate ASI Loader 9.7.4
│   │   ├─ dxgi.dll         薄壳 wrapper
│   │   ├─ nvngx_dlss.dll   56 MB
│   │   └─ nvngx_dlssnr.dll 158 MB
│   └─ scripts/             部署到 <Win64>\scripts\
│       ├─ global.ini       [Plugins] LoadOrder=d3d11.asi,ReShade.asi
│       ├─ ReShade.asi      ReShade 6.8.0.2155
│       ├─ ReShade.ini      ReShade 配置（含 [RenoDX.DLSS5] 大段参数）
│       ├─ renodx-dlss5-v10.5.0.addon64
│       ├─ dlss5-feed.addon64
│       ├─ ReshadeEffectShaderToggler.addon64 / .ini
│       └─ （部署时生成）d3d11.asi、d3dx.ini、d3dx_user.ini、d3dcompiler_47.dll
│          （目录联接）Mods、Core、ShaderFixes、ShaderCache、Screenshots、qaqm → <WWMI>
└─ .github/workflows/release.yml   打 tag 自动打包 zip + PS2EXE 生成 exe 并发 Release
```

---

## 5. 部署 / 卸载流程

**install.ps1 做的事：**
1. 定位游戏目录（读 `XXMI Launcher Config.json` 的 `game_folder`，或全盘搜 `Client-Win64-Shipping.exe`）
2. 定位 `<WWMI>`（必须有 `d3d11.dll` + `Mods`）
3. 清理旧部署：删 `<Win64>` 下 `d3d11.dll`、`dxgi.dll`、`nvngx_dlss.dll`、`nvngx_dlssnr.dll`，删整个 `<Win64>\scripts`
4. 复制 `files\scripts` → `<Win64>\scripts`
5. 从 `<WWMI>` 硬链接 `d3d11.dll→d3d11.asi`、`d3dx.ini`、`d3dx_user.ini`、`d3dcompiler_47.dll`
6. 把 `Mods`、`Core`、`ShaderFixes`、`ShaderCache`、`Screenshots`、`qaqm` 建成**目录联接**（junction）指向 `<WWMI>` 同名目录
7. 硬链接 `files\bin` 四个文件到游戏目录

> 同盘用硬链接/junction，跨盘自动退化为复制。

**启动方式（重要）：** 用**库洛官方启动器/WeGame** 启动，游戏内选 **DirectX 11**。
**绝不能用 XXMI Launcher 点启动** —— 它会把自己那份 `d3d11.dll`（3DMigoto）和 `dxgi.dll`（ReShade 6.6.1）铺进游戏目录，顶掉 ASI 加载链。XXMI Launcher 只用来管理/更新 mod。

---

## 6. 已踩过的坑（★ 血泪清单，动手前必看）

1. **删了 `<Win64>\d3d11.dll` = 拆了加载器** → `scripts` 下所有 `.asi` / `.addon64` 不再被加载，mod、ReShade、DLSS5 全部失效。曾误判为"两份 3DMigoto 重复注入"而删除，已恢复。
2. **不要用 XXMI Launcher 启动游戏**，会覆盖加载链（见上）。
3. **ReShade 效果面板为空** = `ReShade.ini` 的 `EffectSearchPaths` / `TextureSearchPaths` 指向的目录不存在。本机正确值：
   ```
   EffectSearchPaths=D:\mod\reshade-shaders\Shaders\**      （86 个 fx）
   TextureSearchPaths=D:\mod\reshade-shaders\Textures\**    （102 个贴图）
   ```
   路径是相对 ReShade DLL 所在目录（`scripts`）解析的，`scripts\reshade-shaders` 并不存在。
4. **DLSS5 与 NVIDIA AI 插帧可能抢 NGX 钩子**：表现为进游戏后卡死再闪退，系统事件 `Application Error`、异常码 `0xc0000005`、故障模块 `KERNELBASE.dll`；`ReShade.log` 停在 `NGX module scan`。**尚未完全确认**，排查方法是把 `renodx-dlss5-v10.5.0.addon64`、`dlss5-feed.addon64` 改名成 `.addon64.off` 停用做对照。
5. **`nvngx_dlss*.dll` 别删**：游戏自带的 DLSS 运行时，删了游戏内 DLSS 选项会失效。
6. **git 需要配代理**，否则 push 报 `Recv failure: Connection was reset`：
   ```powershell
   git config --global http.proxy http://127.0.0.1:3067
   git config --global https.proxy http://127.0.0.1:3067
   ```
7. **大文件走 Git LFS**：`git clone` 后必须 `git lfs pull`，否则拿到的是指针文件。
8. **CI 用 `shell: pwsh`（PowerShell 7）**：曾经改成 `powershell`(5.1) 导致 `Compress-Archive` 报错；改成 `7z` 又因为 runner 上没有 `7z` 命令失败。**当前可用写法就是 pwsh + Compress-Archive，别再折腾。**
9. **exe 单独打包会失效**：`install.ps1` 依赖同目录的 `files\`，所以 exe 必须和 `files` 在同一个 zip 里（当前是单包发布）。
10. **PS2EXE 生成的 exe 无签名**，会被杀软误报，属正常现象，推荐用 bat 版。

---

## 7. 当前状态

| 项 | 状态 |
|---|---|
| 3DMigoto mods | ✅ 正常 |
| ReShade 效果 | ✅ 路径已修正（指向 `D:\mod\reshade-shaders`），**待启动验证** |
| DLSS5 插件 | ✅ 已重新启用（此前为排查卡死临时改成 `.off`） |
| 卡死闪退 | ⚠️ **未确认根因**。停用 DLSS5 期间游戏正常；DLSS5 恢复后是否会再卡死，需实测 |
| 仓库 | main 分支，`install.ps1` 正常部署 `d3d11.dll`；错误的 v1.2.1 已删除，最新 Release 为 **v1.2** |

**下一步待办：**
1. 启动游戏验证 ReShade 效果是否出现、DLSS5 面板是否回来
2. 若恢复 DLSS5 后再次卡死 → 关掉英伟达 App 的 AI 插帧再测，确认是否为 NGX 钩子冲突
3. 验证通过后，把 `ReShade.ini` 的 shaders 路径处理写进 `install.ps1`（自动检测并写入绝对路径），再发 v1.3
4. Releases 页面清理掉 v1.0 / v1.1 两个旧版本，只留最新

---

## 8. 诊断方法速查

| 症状 | 看哪里 |
|---|---|
| 全部功能失效 | 先看 `<Win64>\d3d11.dll` 还在不在（ASI Loader） |
| ReShade 没起来 | `<Win64>\scripts\ReShade.log` 是否生成；没有 = 加载器没加载插件 |
| ASI Loader 是否初始化 | `<Win64>\dxgi_log.txt` |
| DLSS5 崩溃 | `<Win64>\RenoDX-DLSS5-crash.log`（会指出故障模块） |
| 系统级崩溃 | 事件查看器 → 应用程序 → ID 1000（Application Error） |
| 单个插件的问题 | 把 `scripts\*.addon64` 改名成 `*.addon64.off` 停用，逐个二分 |

**停/启用插件：**
```powershell
cd "D:\Wuthering Waves\Wuthering Waves Game\Client\Binaries\Win64\scripts"
ren renodx-dlss5-v10.5.0.addon64 renodx-dlss5-v10.5.0.addon64.off   # 停用
ren renodx-dlss5-v10.5.0.addon64.off renodx-dlss5-v10.5.0.addon64   # 恢复
```

---

## 9. 仓库与发布

```powershell
cd D:\mod\WWMI-DLSS5-Deploy
git add -A
git commit -m "说明"
git push
git tag v1.3
git push origin v1.3        # 自动打包 zip + exe，发 Release
```

- 大文件（dll / asi / addon64 / zip）走 Git LFS，`.gitattributes` 已配置
- CI：push tag → `windows-latest` → 打包 → PS2EXE 生成 `一键部署.exe`/`一键卸载.exe`（带 `requireAdmin`、`UNICODEEncoding`）→ 发 Release
- 当前 Release 资产：单个 `WWMI-DLSS5-Deploy.zip`（约 143 MB）

---

## 10. 想把它集成进别的项目

三种方式，按推荐度：

1. **直接并入目录**：把整个 `WWMI-DLSS5-Deploy` 复制到目标项目下（本机工作副本里的 LFS 文件是真实文件，直接复制即可，不用走 git）
2. **git submodule**：`git submodule add https://github.com/aiertana/wwmi-dlss5-kit.git <路径>`，注意子模块需要 `git lfs pull` 才有真实 dll
3. **独立调用**：把 `install.ps1` 当外部脚本调用，支持传参
   ```powershell
   powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "<Win64 路径>" -WwmiDir "<WWMI 路径>"
   ```

集成时注意：脚本会**清空并重建** `<Win64>\scripts`，且需要**管理员权限**（硬链接 + junction）。
