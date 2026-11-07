#!/system/bin/sh
LOG=/tmp/xdf_usb.log
exec >> "$LOG" 2>&1
echo "=== xdf_usb $(date) ==="

PARA=/dev/block/platform/bootdevice/by-name/para

if [ -b "$PARA" ]; then
    dd if=/dev/zero of="$PARA" bs=1024 count=4 2>/dev/null && echo "BCB cleared (boot)"
fi

(
    while true; do
        sleep 20
        [ -b "$PARA" ] && dd if=/dev/zero of="$PARA" bs=1024 count=4 2>/dev/null
    done
) &

i=0; UDC=""
while [ $i -lt 60 ]; do
    UDC=$(ls /sys/class/udc 2>/dev/null | head -1)
    [ -n "$UDC" ] && break
    sleep 0.5; i=$((i+1))
done
echo "UDC=$UDC (tries=$i)"
[ -z "$UDC" ] && { echo "no udc"; exit 0; }
setprop sys.usb.controller "$UDC"

i=0
while [ $i -lt 40 ]; do
    [ -d /config/usb_gadget/g1/functions/ffs.adb ] && break
    sleep 0.5; i=$((i+1))
done
echo "gadget dirs: $(ls /config/usb_gadget/g1 2>/dev/null | tr '\n' ' ')"

if ! mount | grep -q usb-ffs/adb; then
    mkdir -p /dev/usb-ffs/adb
    mount -t functionfs adb /dev/usb-ffs/adb 2>/dev/null
fi
echo "ffs mounted: $(mount | grep -c usb-ffs/adb)"

setprop sys.usb.ffs.ready 1
setprop sys.usb.config adb
sleep 1
echo "controller=$(getprop sys.usb.controller) state=$(getprop sys.usb.state)"
echo "adbd=$(getprop init.svc.adbd)  UDC=$(cat /config/usb_gadget/g1/UDC 2>/dev/null)"
echo "=== done ==="
