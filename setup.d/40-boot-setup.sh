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
  dd if=/dev/nvme0n1p2 of=/dev/nvme0n1p3 bs=64M
}

rollback_snapshot()
{
  dd of=/dev/nvme0n1p3 if=/dev/nvme0n1p2 bs=64M
}



echo ""
echo "  ==================================================="
echo "           Press any key to create snapshot!"
echo "  ==================================================="
echo ""

if ! read -t 5 -n 1; then
  banner "Snapshot creation aborted!"
  sleep 5
else
  create_snapshot

  banner "Creating snapshot and rebooting"
  reboot -f
fi

echo ""
echo "  ==================================================="
echo "           Press any key to attempt rollback!"
echo "                Booting up in 15 seconds"
echo "  ==================================================="
echo ""

if ! read -t 15 -n 1; then

  banner "Rollback aborted! The filesystem contents will be preserved!"
  exit 0
else
  rollback_snapshot

  banner "Creating snapshot and rebooting"
  reboot -f
fi
EOM
chmod 755 /etc/initramfs-tools/scripts/local-premount/prompt

update-initramfs -uv
