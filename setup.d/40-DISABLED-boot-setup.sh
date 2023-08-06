#!/bin/bash

set -x
set -e

echo "boot-setup: works, but disabled due to inconveniences"
echo "- Needs nosplash for prompting"
echo "- snapshot can be found by Ubuntu's sidebar, which is annoying"
echo "- Rethink logic:"
echo "  - is 15 sec enough?"
echo "  - Do not try booting after zerofree + snapshot"
echo "  - Maybe snapshot on first boot (so it won't available in the laptop image)"
exit 0

VG="ubuntu-vg"
ORIGIN_LV="ubuntu-lv"
SNAPSHOT_LV="ubuntu-snapshot"

cat <<EOM >/etc/initramfs-tools/hooks/zerofree
#!/bin/sh
PREREQ=""
prereqs()
{
   echo "\$PREREQ"
}

case \$1 in
prereqs)
   prereqs
   exit 0
   ;;
esac

. /usr/share/initramfs-tools/hook-functions

if [ ! -x "/sbin/zerofree" ]; then
  exit 1
fi

copy_exec /sbin/zerofree /sbin
exit 0
EOM
chmod 755 /etc/initramfs-tools/hooks/zerofree

cat <<EOM >/etc/initramfs-tools/scripts/local-premount/prompt
#!/bin/sh
PREREQ="lvm"
prereqs()
{
   echo "\$PREREQ"
}

case \$1 in
prereqs)
   prereqs
   exit 0
   ;;
esac

# Source: thicc-boiz repository from KSZK

set -e

# functions

panic()
{
  echo ""
  echo "ERROR!!!"
  echo "AUTO ROLLBACK FAILED: \${@}"
  exit 1
}

banner()
{
  echo ""
  echo "=== \${@} ==="
  echo ""
  sleep 2
}

create_snapshot()
{
  lvm lvcreate -s -p r -v -n "${SNAPSHOT_LV}" -l '100%ORIGIN' "${VG}/${ORIGIN_LV}"
}

rollback_snapshot()
{
  lvm lvconvert --mergesnapshot -v -i 2 -y "${VG}/${SNAPSHOT_LV}"
}

# main

if [ \$(lvm vgs --noheadings -o vg_name 2>/dev/null | grep "${VG}" | wc -l) -ne "1" ]; then
  panic "The presence of the volume group is dubious!"
fi

if ! lvm lvs --noheadings -o lv_name "${VG}" 2>/dev/null | grep -qs "${ORIGIN_LV}" 2>/dev/null; then
  panic "Origin LV not found!"
fi

if lvm lvs --noheadings -o lv_name "${VG}" 2>/dev/null | grep -qs "${SNAPSHOT_LV}" 2>/dev/null; then
  # Yes snapshot

  echo ""
  echo "  ==================================================="
  echo "       Rollback will be attempted in 15 seconds!"
  echo "                Press any key to abort!"
  echo "  ==================================================="
  echo ""

  if read -t 15 -n 1; then

    banner "Rollback aborted! The filesystem contents will be preserved!"
    exit 0

  fi

  # Perform rollback
  rollback_snapshot
  banner "Rebooting to restored OS..."
  reboot -f # force needed because there are not init system running
  # After that a new snapshot will be created

else
  # No snapshot
  banner "First boot after setting up! Will shrink disk and create snapshot!"

  # Perform snapshot creation
  if [ ! -x "/sbin/zerofree" ]; then
    panic "zerofree executable not found"
  fi

  zerofree /dev/${VG}/${ORIGIN_LV}
  create_snapshot
  banner "Snapshot created!"

fi
EOM
chmod 755 /etc/initramfs-tools/scripts/local-premount/prompt

update-initramfs -uv
