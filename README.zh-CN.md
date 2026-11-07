# android_device_xdf_n1

**简体中文** | [English](README.md)

用于 **华瑞安 KNC G128 / XDF-N1** 平板（MediaTek MT8788，平台 `mt6771`，板型 `tb8788p1_64_bsp`）的 TeamWin Recovery Project (TWRP) 设备树。

- **TWRP 版本**：`V1.0.0-XDF_N1-Built_by_Folralorwns`（基于 TWRP 3.7.0_11，`twrp-11` 分支）
- **设备形态**：A-only，system-as-root，动态分区（`super` 内含 system/vendor）
- **内核**：使用原厂 prebuilt 内核，无需内核源码

## 功能状态

| 功能 | 状态 |
|---|---|
| 启动 / 触摸 / 显示 | ✅ |
| 中文界面 | ✅ |
| 时区 UTC+8 | ✅ |
| ADB（进入主界面后保持） | ✅ |
| MTP | ❌ 主动关闭（见下方说明） |
| 挂载 `super` 内的 logical 分区（system / vendor） | ✅ |
| 备份 / 恢复 / 刷写 boot、recovery | ✅ |
| 自动清理 MTK BCB（不会卡 recovery） | ✅ |
| 横屏界面 | ❌ fbdev 后端不支持旋转 |
| FBE 解密 | ❌ 需要 TrustKernel TEE，recovery 内无法运行 |

## 设备特性（移植前必读）

1. **没有 `misc` 分区。** MTK 的 BCB 存在 **`para`** 分区里。如果 recovery 不清它，每次重启都会回到 recovery。本设备树在三处清理：
   - 启动时清一次
   - 运行期每 20 秒清一次
   - `poweroff.sh` / `rebootsystem.sh` 退出钩子各清一次

2. **硬件按键组合进入 recovery 被阉割。** 只能使用：
   ```bash
   adb reboot recovery
   ```

3. **TWRP 不会执行 `on fs` / `on init` 里的 `exec` 和 `start service`。**
   唯一可靠的钩子是 `/system/bin/postrecoveryboot.sh`（TWRP 会在 UI 启动前执行它）。

4. **USB 使用 configfs，不是老的 android_usb。**
   `init.recovery.usb.rc` 先把 `sys.usb.configfs` 置 1，再补齐
   `sys.usb.controller`、`sys.usb.ffs.ready`、`sys.usb.config=adb`。

5. **必须禁用 MTP**（`TW_EXCLUDE_MTP := true`）。否则 TWRP 进入主界面时会把
   gadget 切换到 `mtp,adb`，而 gadget 只注册了 adb，USB 会直接死掉。

## 编译

### 1. 准备源码

```bash
mkdir -p ~/twrp && cd ~/twrp

# repo 启动器必须走镜像，否则会卡在 googlesource
export REPO_URL=https://mirrors.tuna.tsinghua.edu.cn/git/git-repo

repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp \
  -b twrp-11

repo sync -j8 --force-sync --no-clone-bundle --no-tags
```

> 建议把 `.repo/manifests/default.xml` 里的 AOSP 源
> (`https://android.googlesource.com`) 换成国内镜像，例如
> `https://mirrors.bfsu.edu.cn/git/AOSP` —— 清华镜像对大仓库偶发断流，北外更稳。
>
> TeamWin 的 GitHub fork（`android_bootable_recovery`、`android_system_core`、
> `android_system_sepolicy`、`android_hardware_interfaces`）容易 TLS 断流，
> 可以用 tarball 补：
> ```bash
> curl -L -o core.tar.gz https://codeload.github.com/TeamWin/android_system_core/tar.gz/refs/heads/android-11
> tar xzf core.tar.gz -C system/core --strip-components=1
> ```

### 2. 克隆设备树

```bash
git clone https://github.com/<你的用户名>/android_device_xdf_n1.git device/xdf/n1
```

### 3. 应用源码补丁

```bash
cd ~/twrp/bootable/recovery

git apply ../../device/xdf/n1/patches/0001-version-string.patch
git apply ../../device/xdf/n1/patches/0002-timezone-cst8.patch
```

### 4. 编译

```bash
cd ~/twrp
source build/envsetup.sh
lunch twrp_n1-eng
mka recoveryimage -j$(nproc)
```

产物：`out/target/product/n1/recovery.img`（约 25 MB，分区 32 MB）

> **重要**：只要改动了任何库代码，必须先删除产品输出目录再编译，否则镜像不会更新：
> ```bash
> rm -rf out/target/product/n1
> ```

## 刷入

通过 BROM（mtkclient）：

```bash
mtk.py w recovery recovery.img
mtk.py reset
```

或在 Android 内用 root 直接写分区：

```bash
adb push recovery.img /sdcard/
adb shell su -c "dd if=/sdcard/recovery.img of=/dev/block/by-name/recovery bs=1M; sync"
adb reboot recovery
```

## 恢复原厂 recovery

```bash
mtk.py w recovery stock_recovery.img
```

如果设备卡在 recovery 无法退出，进 BROM 清除 BCB：

```bash
mtk.py e para
mtk.py reset
```

## 已知问题

- **横屏不可用。** 面板为 1600×2176 竖屏，该内核的 fbdev 后端没有实现 minui 的旋转路径，
  设置 `TW_ROTATION := 90` 会黑屏。目前使用竖屏主题，按 1.481× / 1.133× 缩放。
- **FBE 解密不可用。** `/data` 使用 FBE 加密，keymaster 4.0 由 TrustKernel TEE 提供。
  开启 `TW_INCLUDE_CRYPTO` 会导致 TWRP 无限重启（keymaster 栈在 recovery 内起不来）。
  需要读取内置存储时，请在 Android 内使用 `adb pull`。

## 目录结构

```
BoardConfig.mk
device.mk
recovery.fstab
twrp_n1.mk
AndroidProducts.mk
prebuilt/
├── Image.gz-dtb          # 原厂内核 + 附加 DTB
└── dtb                   # boot 头使用的独立 DTB
recovery/root/
├── init.recovery.usb.rc  # 启用 configfs 并启动 USB 服务
├── sbin/xdf_usb.sh       # USB 初始化 + BCB 清理（含定时）
└── system/bin/
    ├── postrecoveryboot.sh  # 启动钩子
    ├── poweroff.sh          # 关机前清 BCB
    └── rebootsystem.sh      # 重启系统前清 BCB
patches/
├── 0001-version-string.patch
└── 0002-timezone-cst8.patch
```

## 致谢

- [TeamWin Recovery Project](https://github.com/TeamWin)
- [minimal-manifest-twrp](https://github.com/minimal-manifest-twrp)

## 许可证

本仓库内所有原创文件（构建配置、shell 脚本、recovery 钩子）采用
**GNU General Public License v3.0**，完整文本见 [LICENSE](LICENSE)。

`prebuilt/` 下的内核镜像与 DTB **不受 GPL 约束**，版权归原厂所有，
仅为了使 recovery 镜像在该设备上可用而分发。
