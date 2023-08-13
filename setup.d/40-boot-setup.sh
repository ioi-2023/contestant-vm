#!/bin/bash

set -x
set -e

sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s/splash//' /etc/default/grub
update-grub2


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
  dd bs=1048576 if=/dev/nvme0n1p2 of=/diskimage/image.img
  touch /diskimage/snapshot.created
}

rollback_snapshot()
{
  dd bs=1048576 if=/diskimage/image.img of=/dev/nvme0n1p2
}

mkdir /diskimage
mount /dev/nvme0n1p3 /diskimage


if [ -f "/diskimage/snapshot.created" ]; then
  echo ""
  echo "  ==================================================="
  echo "           Press any key to create snapshot!"
  echo "  ==================================================="
  echo ""

  if ! read -t 5 -n 1; then
    banner "Snapshot creation aborted!"
    sleep 3
  else
    banner "Creating snapshot"
    create_snapshot

    banner "Shutting down"
    poweroff -f
  fi

else
  echo ""
  echo "  ==================================================="
  echo "             Snapshot creation disabled,"
  echo "               snapshot already exists!"
  echo "  ==================================================="
  echo ""
fi



echo ""
echo "  ==================================================="
echo "           Press any key to attempt rollback!"
echo "                Booting up in 15 seconds"
echo "  ==================================================="
echo ""

if ! read -t 5 -n 1; then

  banner "Rollback aborted! The filesystem contents will be preserved!"
  exit 0
else
  echo "Rolling back"
  rollback_snapshot

  banner "Rebooting"
  reboot -f
fi
EOM
chmod 755 /etc/initramfs-tools/scripts/local-premount/prompt

update-initramfs -uv
