# android_device_xdf_n1

**English** | [简体中文](README.zh-CN.md)

TeamWin Recovery Project (TWRP) device tree for **华瑞安 KNC G128 / XDF-N1** tablet
(MediaTek MT8788, platform `mt6771`, board `tb8788p1_64_bsp`).

- **TWRP**: `V1.0.0-XDF_N1-Built_by_Folralorwns` (based on TWRP 3.7.0_11, `twrp-11` branch)
- **Device**: A-only, system-as-root, dynamic partitions (`super` contains system/vendor)
- **Kernel**: stock prebuilt kernel (no kernel source required)

## Status

| Feature | Status |
|---|---|
| Boot / touch / display | ✅ |
| Chinese UI | ✅ |
| Timezone UTC+8 | ✅ |
| ADB (stays up after UI loads) | ✅ |
| MTP | ❌ disabled on purpose (see notes) |
| Mount logical `system` / `vendor` from `super` | ✅ |
| Backup / restore / flash boot & recovery | ✅ |
| Auto-clear MTK BCB (no recovery loop) | ✅ |
| Landscape UI | ❌ fbdev backend does not support rotation |
| FBE decryption | ❌ needs TrustKernel TEE, cannot run inside recovery |

## Device quirks (read before porting)

1. **No `misc` partition.** MTK stores the BCB in **`para`**. If recovery does not
   clear it, every reboot lands back in recovery. This tree clears it in three
   places: at boot, every 20 s at runtime, and from `poweroff.sh` /
   `rebootsystem.sh` exit hooks.

2. **Hardware key combination for recovery is disabled.** Use:
   ```bash
   adb reboot recovery
   ```

3. **TWRP ignores `exec` and `start service` from `on fs` / `on init`.**
   The only reliable hook is `/system/bin/postrecoveryboot.sh`, which TWRP runs
   before the UI starts.

4. **USB uses configfs, not legacy android_usb.** `init.recovery.usb.rc` sets
   `sys.usb.configfs=1`, then fills in `sys.usb.controller`,
   `sys.usb.ffs.ready` and `sys.usb.config=adb`.

5. **MTP must stay disabled** (`TW_EXCLUDE_MTP := true`). Otherwise TWRP switches
   the gadget to `mtp,adb` on entering the main UI and the USB connection dies
   because the gadget only exposes adb.

## Building

### 1. Sync sources

```bash
mkdir -p ~/twrp && cd ~/twrp

# repo launcher must use a mirror, otherwise it stalls on googlesource
export REPO_URL=https://mirrors.tuna.tsinghua.edu.cn/git/git-repo

repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp \
  -b twrp-11

repo sync -j8 --force-sync --no-clone-bundle --no-tags
```

> Replace the AOSP remote in `.repo/manifests/default.xml`
> (`https://android.googlesource.com`) with a local mirror such as
> `https://mirrors.bfsu.edu.cn/git/AOSP` — the TUNA mirror occasionally drops
> large repositories.
>
> TeamWin's GitHub forks (`android_bootable_recovery`, `android_system_core`,
> `android_system_sepolicy`, `android_hardware_interfaces`) are prone to TLS
> failures. Fall back to tarballs if needed:
> ```bash
> curl -L -o core.tar.gz https://codeload.github.com/TeamWin/android_system_core/tar.gz/refs/heads/android-11
> tar xzf core.tar.gz -C system/core --strip-components=1
> ```

### 2. Clone this tree

```bash
git clone https://github.com/<you>/android_device_xdf_n1.git device/xdf/n1
```

### 3. Apply source patches

```bash
cd ~/twrp/bootable/recovery

git apply ../../device/xdf/n1/patches/0001-version-string.patch
git apply ../../device/xdf/n1/patches/0002-timezone-cst8.patch
```

### 4. Build

```bash
cd ~/twrp
source build/envsetup.sh
lunch twrp_n1-eng
mka recoveryimage -j$(nproc)
```

Output: `out/target/product/n1/recovery.img` (~25 MB, partition is 32 MB)

> **Important:** after changing any library source, delete the product output
> first or the image will not be rebuilt:
> ```bash
> rm -rf out/target/product/n1
> ```

## Flashing

Via BROM (mtkclient):

```bash
mtk.py w recovery recovery.img
mtk.py reset
```

Or from Android with root:

```bash
adb push recovery.img /sdcard/
adb shell su -c "dd if=/sdcard/recovery.img of=/dev/block/by-name/recovery bs=1M; sync"
adb reboot recovery
```

## Recovery

Flash the stock recovery back:

```bash
mtk.py w recovery stock_recovery.img
```

If the device is stuck booting into recovery, clear the BCB in BROM mode:

```bash
mtk.py e para
mtk.py reset
```

## Known issues

- **No landscape UI.** The panel is 1600x2176 portrait and this kernel's fbdev
  backend does not implement minui's rotation path. `TW_ROTATION := 90` renders
  a black screen. The portrait theme is scaled 1.481x / 1.133x instead.
- **No FBE decryption.** `/data` is encrypted with FBE and keymaster 4.0 backed
  by TrustKernel TEE. Enabling `TW_INCLUDE_CRYPTO` makes TWRP bootloop because
  the keymaster stack cannot start inside recovery. Use `adb pull` from Android
  to access internal storage data.

## Tree layout

```
BoardConfig.mk
device.mk
recovery.fstab
twrp_n1.mk
AndroidProducts.mk
prebuilt/
├── Image.gz-dtb          # stock kernel + appended DTB
└── dtb                   # standalone DTB for the boot header
recovery/root/
├── init.recovery.usb.rc  # enable configfs + start USB service
├── sbin/xdf_usb.sh       # USB setup + BCB clearing (incl. periodic)
└── system/bin/
    ├── postrecoveryboot.sh  # boot hook
    ├── poweroff.sh          # clear BCB before power off
    └── rebootsystem.sh      # clear BCB before rebooting to system
patches/
├── 0001-version-string.patch
└── 0002-timezone-cst8.patch
```

## Credits

- [TeamWin Recovery Project](https://github.com/TeamWin)
- [minimal-manifest-twrp](https://github.com/minimal-manifest-twrp)

## License

All original files in this repository (build configuration, shell scripts and
recovery hooks) are licensed under the **GNU General Public License v3.0**.
See [LICENSE](LICENSE) for the full text.

Files under `prebuilt/` (the kernel image and DTB) are **NOT** covered by the
GPL. They remain the property of the original vendor and are redistributed
solely so that the recovery image is functional on the target device.
