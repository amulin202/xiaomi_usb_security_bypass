# Xiaomi USB Security Bypass

> 免小米账号 / SIM 卡，root 后强制开启 MIUI「USB 调试(安全设置)」「USB 安装」「FASTBOOT 刷机模式」的 Magisk 模块。

[![Magisk](https://img.shields.io/badge/Magisk-20.4%2B-00B8FF.svg)](https://github.com/topics/magisk-module)
[![Android](https://img.shields.io/badge/Android-9%2B-3DDC84.svg)](https://www.android.com/)
[![MIUI](https://img.shields.io/badge/MIUI-10~14%20%2F%20HyperOS-FF6900.svg)](https://www.mi.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 目录

- [解决的问题](#解决的问题)
- [适用机型](#适用机型)
- [原理](#原理)
- [安装](#安装)
- [验证是否生效](#验证是否生效)
- [与 scrcpy 联动](#与-scrcpy-联动)
- [卸载](#卸载)
- [自行构建刷机包](#自行构建刷机包)
- [仓库文件说明](#仓库文件说明)
- [故障排查](#故障排查)
- [安全与免责声明](#安全与免责声明)
- [致谢与参考](#致谢与参考)

---

## 解决的问题

小米 / 红米（MIUI）手机连接电脑后，**画面能看、鼠标键盘不能控制**，典型报错：

```text
java.lang.SecurityException: Injecting to another application requires INJECT_EVENTS permission
```

根因：MIUI 把“反控 / 模拟点击”权限拆成了一个独立开关 —— **「USB 调试(安全设置)」**。它和普通「USB 调试」是两项不同的开关：

| 开关 | 作用 | 开启前提 |
|---|---|---|
| USB 调试 | 允许 adb 连接（看屏幕、文件、日志） | 仅需弹窗授权 |
| **USB 调试(安全设置)** | 允许 adb / scrcpy **模拟点击、按键** | **登录小米账号 + 插入 SIM 卡** |
| **USB 安装** | 允许 `adb install` | 登录小米账号 + 插入 SIM 卡 |
| **FASTBOOT 刷机模式** | 允许电脑通过 USB 刷机 | 同上 |

`scrcpy`、`Total Control`、`monkey`、`uiautomator`、`appops`、`pm grant` 等都会受此限制。

典型症状：在「开发者选项」里点这三项开关，**刚勾上就自己弹回**，或弹出“需要登录小米账号 / 插入 SIM 卡”的提示 —— 因为 MIUI 在点击时强制走了一遍联网校验。本模块不是去骗过校验，而是在每次开机时**直接把这两层开关的底层状态写成“已启用”**，绕开整条验证链路，**不需要插卡、不需要登录**。

## 适用机型

- 已解锁 Bootloader 并刷入 **Magisk** 的小米 / 红米手机（须有 root）
- MIUI 10 ~ 14、HyperOS 均已有成功案例；Android 9 及以上通用
- 已在 **小米 9 Pro 5G (crux) + MIUI 12** 与 **小米 8 (dipper) + MIUI 12.5** 实测通过

> ⚠️ 普通 adb（如 Shizuku）权限不够，必须完整 root（Magisk / KernelSU 亦可，脚本自带 `resetprop` 兜底）。

## 原理

MIUI 这三个开关的状态分散在**两层**，缺一层就会“看着开了其实没开”：

**第一层：persist 系统属性**（由 `system_server` 动态读取）

| 属性 | 对应开关 |
|---|---|
| `persist.security.adbinput` | USB 调试(安全设置)（模拟点击/按键） |
| `persist.security.adbinstall` | USB 安装 |
| `persist.fastboot.enable` | FASTBOOT 刷机模式 |

**第二层：手机管家自己的配置**（由 `com.miui.securitycenter` 读取，它才真正决定 `adb install` 是否被放行）

- `/data/data/com.miui.securitycenter/shared_prefs/*.xml` 中的
  `security_adb_install_enable`、`permcenter_install_intercept_enabled` 等条目；
- `global` / `secure` / `system` 三个 settings 命名空间中的
  `adb_install_enabled`、`usb_install_enabled`、`security_adb_install_enable` 等行。

UI 上打开开关时，MIUI 会连网验证小米账号并校验 SIM 卡，通过后才写入这两层；验证失败时开关被弹回，而**系统在真正安装 / 注入事件时只检查这两层的当前值**。

因此 root 后直接把它们全部置为“已启用”即可。模块在开机时自动完成：

1. **`system.prop`** —— Magisk 在启动早期用 `resetprop` 应用属性（不经过 property_service，无 SELinux 限制）；
2. **`post-fs-data.sh`** —— 在 zygote 与各 App 启动**之前**改写手机管家 prefs，此时文件没人占用，改完即生效，无需重启任何进程；
3. **`service.sh`** —— 开机完成后兜底：再设一遍属性、写入三组 settings 行、复查 prefs；只有当 prefs 真的被改坏时才重启手机管家让它重读。

双保险保证开机后两层状态一定正确，无论系统更新、云端配置覆盖还是开关被点回。

## 安装

### 方式一：Magisk 应用（推荐）

1. 下载 Release 里的 `xiaomi_usb_security_bypass_vX.Y.zip`（或自行构建，见下文）；
2. 打开 **Magisk App → 模块 → 从本地安装**，选择该 zip；
3. **重启手机**；
4. 在“模块”列表确认 `Xiaomi USB Security Bypass` 已启用。

### 方式二：命令行（免手动操作）

```bash
# 将 zip 推到手机后，root shell 安装
adb push xiaomi_usb_security_bypass_v1.1.zip /sdcard/Download/
adb shell su -c "magisk --install-module /sdcard/Download/xiaomi_usb_security_bypass_v1.1.zip"

# 重启生效
adb reboot
```

> 首次用 Magisk 安装模块必须重启一次，模块文件才会落盘并执行 `post-fs-data.sh` / `service.sh`。

### 方式三：手动（不想装模块时应急）

```bash
adb shell su -c setprop persist.security.adbinput 1
adb shell su -c setprop persist.security.adbinstall 1
adb shell su -c setprop persist.fastboot.enable 1
```

> ⚠️ 只设属性在部分 MIUI 版本上不足以放行 `adb install`，还需要手机管家那一层 —— 装模块最省事。
> ⚠️ Windows 下 `adb shell su -c '多条; 命令'` 的引号常被吞掉，务必**逐条执行**。

## 验证是否生效

```bash
# 1) 三个属性都应为 1
adb shell getprop persist.security.adbinput
adb shell getprop persist.security.adbinstall
adb shell getprop persist.fastboot.enable

# 2) 手机管家那一层（模块开机已写入）
adb shell settings get secure adb_install_enabled
adb shell settings get global adb_enabled

# 3) 输入注入测试：能回桌面且无报错即代表已放行
adb shell input keyevent KEYCODE_HOME

# 4) 端到端：随便装个 apk，应为 Success 而不是 INSTALL_FAILED_USER_RESTRICTED
adb install -r your.apk
```

放行前报 `SecurityException: ... INJECT_EVENTS permission`，放行后静默成功。

想看模块自己做了什么，抓一行日志即可：

```bash
adb shell su -c "logcat -d -s XiaomiUsbBypass:V"
# 例：done: adbinstall=1 adbinput=1 fastboot=1 prefs_rewritten=0
```

**Magisk 操作按钮**：在 Magisk App 的模块列表点本模块的“操作”按钮，会立刻重跑一遍全部置位逻辑（`action.sh`），
适用于开关被 MIUI 弹回之后不想重启手机的场景。输出直接显示在 App 里。

## 与 scrcpy 联动

```bash
# 下载 scrcpy Windows 版并解压后，直接运行
scrcpy.exe
```

生效后即可用鼠标 / 键盘完整控制手机。常用快捷键：`右键`=返回、`中键`=HOME、`Alt+f`=全屏。

## 卸载

**Magisk App → 模块 → Xiaomi USB Security Bypass → 卸载 → 重启** 即可。

> 卸载模块只停止“开机自动置位”，已写入的 persist 属性与 settings 行会保留，直到被系统 / 其他操作改回。

被改写过的手机管家 prefs 会留下同名备份，按需回滚：

```bash
adb shell su -c "cd /data/data/com.miui.securitycenter/shared_prefs && \
  cp remote_provider_preferences.xml.usb_bypass.bak remote_provider_preferences.xml"
```

## 自行构建刷机包

仓库根目录即模块源码，克隆后可一键打包：

```bash
git clone https://github.com/CHERWING/xiaomi_usb_security_bypass.git
cd xiaomi_usb_security_bypass
python build_zip.py      # 输出 xiaomi_usb_security_bypass_vX.Y.zip
```

打包脚本用 Python 标准库 `zipfile`，无第三方依赖，且会给脚本写入可执行位（0755）。

## 仓库文件说明

| 文件 | 说明 |
|---|---|
| `module.prop` | Magisk 模块元信息（id / name / version / author / description） |
| `system.prop` | 开机早期由 Magisk resetprop 应用的属性清单 |
| `common.sh` | 公共逻辑：日志、属性置位、手机管家 prefs 改写、settings 写入（被下列脚本 source） |
| `post-fs-data.sh` | 开机早期改写手机管家 prefs（抢在 App 启动前，无需重启进程） |
| `service.sh` | 开机完成后兜底：属性 + settings + prefs 复查，必要时重启手机管家 |
| `action.sh` | Magisk 操作按钮：免重启重跑全部置位逻辑 |
| `customize.sh` | 安装时确保脚本可执行 |
| `build_zip.py` | 一键打包脚本（生成可刷入的 zip） |
| `README.md` | 本文档 |

## 故障排查

| 现象 | 原因 / 处理 |
|---|---|
| 点「USB 安装 / USB 调试(安全设置)」开关自己弹回 | 正常：点击必然触发小米账号 + SIM 校验。模块的作用是让开关**开机即处于已启用状态**，不要再去点它；若已点回，用 Magisk 的“操作”按钮或重启手机恢复 |
| 属性是 1 但 scrcpy 仍不能控制 | 重启一次手机；确认开发者选项里「USB 调试」本身已开 |
| 属性是 1、但 `adb install` 报 `INSTALL_FAILED_USER_RESTRICTED` | 手机管家那层没写进去：`adb shell su -c "logcat -d -s XiaomiUsbBypass:V"` 看是否有 `ERROR: could not patch prefs`；再跑一次“操作”按钮 |
| 重启后属性变回 0 | 模块未启用 / 被移除；Magisk 版本过低（需 ≥ 20.4） |
| 安装后模块列表为空 | 重启后才会显示，确认 zip 为官方打包（根含 module.prop） |
| 注入仍报 INJECT_EVENTS | 确认前台当前用户与 adb 会话一致；个别双开/分身环境请切回主空间测试 |
| 找不到「USB 调试(安全设置)」开关 | 属正常，模块生效后该开关状态由属性驱动，功能不受 UI 显示影响 |
| 跑“操作”按钮后 adb 连接断了几秒 | 正常：写入 `adb_enabled` 与重启手机管家会让 USB 链路重置，几秒后自动恢复 |

## 安全与免责声明

- 本模块会**降低设备安全性**：开启后，任何拿到你数据线 / 无线调试权限的人都能远程模拟点击、安装应用。**请勿在公用设备、演示机或存有敏感数据的手机上使用**，使用完建议卸载并重置相关开关。
- 模块会同时关闭手机管家的“安装拦截”（`permcenter_install_intercept_enabled=false`）以放行 `adb install`，即放弃 MIUI 的安装前扫描。
- 开启 FASTBOOT 模式后，电脑可直接刷机，误操作有变砖风险。
- 本项目仅供个人技术研究与合法用途。**请遵守当地法律法规与设备厂商条款**，因使用本模块造成的任何损失由使用者自行承担。

## 致谢与参考

- 思路来源与验证：[不登陆小米账号启用 MIUI 的 ADB 调试(安全设置)](https://blog.remiki.ren/archives/5/) · [使用 root 跳过小米 USB 安装应用确认](https://bl.ocks.org/the-eric-kwok/19b378d5ff0b02271a8307b144a4db35) · [XDA: Settings in Developer Options](https://xdaforums.com/t/settings-in-developer-options.4357631/)
- 相关工具：[scrcpy](https://github.com/Genymobile/scrcpy) · [Magisk](https://github.com/topjohnwu/Magisk)

## License

[MIT](LICENSE) © 2026 CHERWING
