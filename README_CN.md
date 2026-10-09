# KernelSU LSPosed 复活 & eUICC 热重启保护模块

[English](README.md) | [简体中文](README_CN.md)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![KernelSU Compatible](https://img.shields.io/badge/KernelSU-Supported-brightgreen.svg)]()
[![Magisk / APatch](https://img.shields.io/badge/Magisk%20%2F%20APatch-Supported-orange.svg)]()
[![Android 12-15](https://img.shields.io/badge/Android-12%20--%2015-green.svg)]()

专为 KernelSU / Magisk / APatch 设计的高级系统模块。在实现**免解锁（免BL）环境下的 LSPosed 守护进程与 ZygiskSU 热重启自动复活**的同时，首创性地解决了**任意热重启后实体 eSIM 卡（eUICC / OMAPI）通道泄漏瘫痪**的底层硬件冲突。

---

## 🔍 问题背景与核心痛点

在现代 Android 设备上（尤其是高通骁龙平台及小米 HyperOS / AOSP），许多进阶玩家同时使用：
1. **可移除实体 eSIM 卡**（如 5ber、eSIM.gg 或外置读卡器），通过 **EasyEUICC** / OpenEUICC 管理；
2. **热重启（软重启 / 杀 Zygote）模块**，用于免 BL 快速唤醒 LSPosed 或重载系统框架。

在过去，任何形式的热重启都会触发一个致命 Bug：
> **EasyEUICC 提示：“此应用在此设备上未检测到可访问的可移除 eSIM 卡。请插入兼容卡片或 USB 读卡器。”**

在此项目发布前，**唯一的解决办法是进行完全的冷关机/硬重启（完全断电重启）**，这完全违背了软重启的初衷。

---

## 🔬 底层技术原理解析

### 1. ISO 7816-4 智能卡逻辑通道泄漏
智能卡（包括 eSIM / eUICC Applet）严格遵循 ISO/IEC 7816-4 与 GlobalPlatform 规范。芯片上的逻辑通道是**有状态的（Stateful）**：
* 当 EasyEUICC 通过 OMAPI 向 ISD-R（发行者安全域根）打开一条逻辑通道时，该通道在物理芯片内部持续保持占用状态，直到主机显式发送 `MANAGE CHANNEL [CLOSE]` APDU 命令（`00 70 80 xx`）。
* 当系统发生热重启（`kill -9 zygote` 或系统框架崩溃），Android 进程被内核瞬间杀死，无法触发任何应用生命周期或析构回调，导致从未向实体卡发送通道关闭指令。

### 2. 基带硬件供电连续性（为什么只有冷重启能恢复？）
在传统的系统关机或硬重启中，电源管理芯片（PMIC）会重置所有供电轨，SIM 卡槽的供电（`VCC`）彻底归零，触发硬件上电复位（Power-On Reset, POR）。
然而在**热重启**中：
* Linux 内核与基带子系统（Modem Subsystem / Hexagon QDSP6）**从未断电或重启**；
* SIM 卡槽持续供电；
* 物理 eUICC 芯片坚信上一会话分配的逻辑通道仍然被占用。当重启后的新进程再次请求打开通道时，卡片直接返回硬件错误 `6A 81`（*功能不支持 / 通道资源耗尽*）。

### 3. Vendor Secure Element HAL 状态脱节
* Android 系统的安全芯片硬件抽象层（`android.hardware.secure_element` HAL）是以独立 Daemon 形式常驻在 `init` 守护进程下的，不受 Zygote 控制。
* 热重启时，该 HAL 不会重启，其内部状态机、QMI UIM 驱动句柄依然绑定在已经死亡的旧客户端会话上，陷入假死状态。

### 4. 框架 AccessControlEnforcer 死锁
* Zygote 重启后，`com.android.se`（`SecureElementService`）重新初始化，并在 `Terminal.java` 中调用 `initializeAccessControl()` 试图读取卡内的 ARA-M 权限规则。
* 由于通道打开失败抛出异常，`mAccessControlEnforcer` 被框架置为 `null`。
* 此后，EasyEUICC 调用 OMAPI 的任何 `openLogicalChannel()` 请求都会被抛出 `SecurityException`，最终导致可用端口数量归零。

---

## 💡 解决方案架构

本模块引入了 **三阶段硬件与框架同步恢复流水线**：

```
[用户触发 Action 或执行热重启]
           │
           ▼
[阶段 1: 重启前优雅拆毁]
   ├── 强制停止 EasyEUICC (im.angry.easyeuicc)
   └── 强制停止 Secure Element 服务 (com.android.se)
           │
           ▼
[阶段 2: 核心复活与框架热重启]
   ├── 原生二进制文件执行 LSPosed ZygiskSU 注入桥接
   └── 重启 Zygote / system_server
           │
           ▼
[阶段 3: 重启后硬件与 HAL 状态复位]
   ├── 终止 Vendor HAL 守护进程 (pkill -9 android.hardware.secure_element)
   │     └─► 由 init 自动重新拉起拥有全新 QMI 客户端的干净 HAL
   ├── 切换基带射频电源 (svc telephony radio off -> on)
   │     └─► 基带在 UICC 总线上强制重发 ATR（复位应答）序列，冲刷全部孤立通道
   └── 重启 com.android.se 重新绑定至新 HAL 并重载权限规则
```

---

## 🚀 核心特性

* **全自动 eUICC 保护**：热重启后 EasyEUICC 立即秒识别 5ber / eSIM.gg 卡片，再也不需要任何冷重启。
* **免 BL 锁 LSPosed 复活**：一键唤醒 LSPosed 守护进程与模块注入。
* **彻底移除失效远程网络请求**：完全清除了原版中所有已 404 失效的作者服务器（`jx.yhyun.asia`）网络检测代码，刷入纯离线、零等待、保护隐私。
* **独立 CLI 修复工具 (`fix-euicc`)**：直接安装到系统 `/system/bin/fix-euicc`。如果你的系统因任何其他第三方应用意外触发了软重启，只需在 Termux 或 Root 终端中执行 `su -c fix-euicc`，2 秒内立刻恢复 eUICC 可用性。

---

## 📦 项目文件结构

```
├── .github/
│   └── workflows/
│       └── release.yml          # GitHub CI/CD: 发布 Tag 时自动打包 flashable zip
├── system/
│   └── bin/
│       └── fix-euicc            # 独立的 CLI 修复脚本
├── webroot/
│   └── index.html               # KernelSU Manager WebUI 页面
├── action.sh                    # KernelSU Action 运行脚本（串联复活与 eUICC 保护）
├── customize.sh                 # 纯离线安装脚本
├── service.sh                   # 后台常驻服务监视器
├── module.prop                  # Magisk / KernelSU 元数据
├── main                         # 经 SHA-256 校验的官方原生复活二进制
├── YHyc                         # 原生辅助工具
├── build.py                     # 一键打包可刷入 ZIP 的 Python 工具
├── LICENSE                      # GNU General Public License v3.0
├── README.md                    # 英文文档
└── README_CN.md                 # 中文文档
```

---

## 🛠️ 安装说明

1. 前往本仓库的 [Releases](../../releases) 页面下载最新版 `KernelSU_LSPosed_eUICC_Fix.zip`。
2. 打开 **KernelSU Manager**、**Magisk** 或 **APatch**。
3. 选择 **模块** -> **从本地安装**，选择下载的压缩包。
4. 重启一次手机使模块完整生效。

---

## 📱 使用方法

### 方法 1：通过 KernelSU Manager 触发（推荐）
1. 打开 **KernelSU** 应用。
2. 进入 **模块** 页面。
3. 找到 **KernelSU LSPosed & eUICC Fix**，点击右侧的 **操作 (Action)** 按钮。
4. 模块将自动释放旧通道、热重启手机、重新唤醒 LSPosed 并复位基带与 HAL。
5. 重新进入 **EasyEUICC**，eSIM 配置文件恢复正常读写。

### 方法 2：命令行紧急修复（第三方热重启后）
如果其他模块触发了软重启导致 EasyEUICC 读不出卡，在 **Termux** 或 Root 终端中运行：
```bash
su -c fix-euicc
```
片刻即可恢复通道识别。

---

## 🔨 本地构建

如果你需要自行修改并打包：

```bash
git clone https://github.com/badgayisme-blip/Fix_lspd_in_locked_bootloader_and_prevent_EUICC_from_dying_after_hotboot.git
cd Fix_lspd_in_locked_bootloader_and_prevent_EUICC_from_dying_after_hotboot

# 运行打包脚本
python3 build.py
```
生成的刷机包位于根目录下的 `KernelSU_LSPosed_eUICC_Fix.zip`。

---

## 📜 鸣谢与开源协议

* 原始免 BL 复活机制来自 **酷安@月虹yh**。
* eUICC OMAPI 通道保护、基带复位方案与代码重构由 **Antigravity** 研发。
* 本项目基于 [GNU General Public License v3.0](LICENSE) 开源。
