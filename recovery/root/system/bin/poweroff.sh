#!/system/bin/sh
PARA=/dev/block/platform/bootdevice/by-name/para
if [ -b "$PARA" ]; then
    dd if=/dev/zero of="$PARA" bs=1024 count=4 2>/dev/null
    sync
fi
exit 0
