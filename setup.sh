#!/bin/bash
source ./config.sh

error() {
	local lineno="$1"
	local message="$2"
	local code="${3:-1}"
	if [[ -n "$message" ]] ; then
		echo "Error at or near line ${lineno}: ${message}; exiting with status ${code}"
	else
		echo "Error at or near line ${lineno}; exiting with status ${code}"
	fi
	exit "${code}"
}
trap 'error ${LINENO}' ERR

VERSION="test$(date +%m%d)"
ANSIBLE_PASSWD="ansible"

if [ -f "config.local.sh" ]; then
	source config.local.sh
fi

# Fix up date/time

timedatectl set-timezone Europe/Budapest
#vmware-toolbox-cmd timesync enable
hwclock -w

# Disable needrestart prompt
export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

# Update packages

apt -y update
apt -y upgrade

apt -y install ubuntu-desktop-minimal

# Networking: tell netplan to use NetworkManager

cat >/etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: NetworkManager
EOF

netplan generate
netplan apply

# Install tools needed for management and monitoring

apt -y install net-tools openssh-server ansible xvfb tinc oathtool imagemagick \
	aria2

# Install local build tools

apt -y install build-essential autoconf autotools-dev python-is-python3

# Install packages needed by contestants

apt -y install emacs neovim \
	geany gedit joe kate kdevelop nano vim vim-gtk3 \
	ddd valgrind visualvm ruby python3-pip konsole

# Install browser

apt -y install firefox

# Install atom's latest stable version
sudo apt install git libasound2 libcurl4 libgbm1 libgcrypt20 libgtk-3-0 libnotify4 libnss3 libglib2.0-bin xdg-utils libx11-xcb1 libxcb-dri3-0 libxss1 libxtst6 libxkbfile1
wget https://github.com/atom/atom/releases/download/v1.60.0/atom-amd64.deb
sudo dpkg -i atom-amd64.deb
sed 's/^Exec=.*$/& --no-sandbox/' -i /usr/share/applications/atom.desktop

# Install snap packages needed by contestants

snap install --classic code
snap install --classic sublime-text

# Install Eclipse
aria2c -x4 -d /tmp -o eclipse.tar.gz "https://eclipse.mirror.liteserver.nl/technology/epp/downloads/release/2023-06/R/eclipse-cpp-2023-06-R-linux-gtk-x86_64.tar.gz"
tar zxf /tmp/eclipse.tar.gz -C /opt
rm /tmp/eclipse.tar.gz
wget -O /usr/share/pixmaps/eclipse.png "https://icon-icons.com/downloadimage.php?id=94656&root=1381/PNG/64/&file=eclipse_94656.png"
cat - <<EOM > /usr/share/applications/eclipse.desktop
[Desktop Entry]
Name=Eclipse
Exec=/opt/eclipse/eclipse
Type=Application
Icon=eclipse
EOM

# Install python3 libraries

pip3 install matplotlib

# Copy IOI stuffs into /opt

mkdir -p /opt/ioi
cp -a bin sbin misc /opt/ioi/
cp config.sh /opt/ioi/
mkdir -p /opt/ioi/run
mkdir -p /opt/ioi/store
mkdir -p /opt/ioi/config
mkdir -p /opt/ioi/store/log
mkdir -p /opt/ioi/store/screenshots
mkdir -p /opt/ioi/store/submissions
mkdir -p /opt/ioi/config/ssh

# Latest as of 2023-05-20
aria2c -x 4 -d /tmp -o cpptools-linux.vsix "https://github.com/microsoft/vscode-cpptools/releases/download/v1.15.4/cpptools-linux.vsix"
wget -O /tmp/vscodevim.vsix "https://github.com/VSCodeVim/Vim/releases/download/v1.25.2/vim-1.25.2.vsix"
rm -rf /tmp/vscode
mkdir /tmp/vscode
mkdir /tmp/vscode-extensions
code --install-extension /tmp/cpptools-linux.vsix --extensions-dir /tmp/vscode-extensions --user-data-dir /tmp/vscode
tar jcf /opt/ioi/misc/vscode-extensions.tar.bz2 -C /tmp/vscode-extensions .
cp /tmp/vscodevim.vsix /opt/ioi/misc
rm -rf /tmp/vscode-extensions

# Add default timezone
echo "Europe/Budapest" > /opt/ioi/config/timezone

# Default to enable screensaver lock
touch /opt/ioi/config/screenlock

# Create IOI account
/opt/ioi/sbin/mkioiuser.sh

# Set IOI user's initial password
echo "ioi:ioi" | chpasswd

# Fix permission and ownership
chown ioi.ioi /opt/ioi/store/submissions
chown ansible.syslog /opt/ioi/store/log
chmod 770 /opt/ioi/store/log

# Add our own syslog facility

echo "local0.* /opt/ioi/store/log/local.log" >> /etc/rsyslog.d/10-ioi.conf

# Add custom NTP to timesyncd config

cat - <<EOM > /etc/systemd/timesyncd.conf
[Time]
NTP=time.windows.com time.nist.gov
EOM

# Don't list ansible user at login screen

mkdir -p /var/lib/AccountsService/users
cat - <<EOM > /var/lib/AccountsService/users/ansible
[User]
Language=
XSession=gnome
SystemAccount=true
EOM

chmod 644 /var/lib/AccountsService/users/ansible

# GRUB config: quiet, and password for edit

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/"$/ quiet splash"/' /etc/default/grub
GRUB_PASSWD=$(echo -e "$ANSIBLE_PASSWD\n$ANSIBLE_PASSWD" | grub-mkpasswd-pbkdf2 | awk '/hash of / {print $NF}')

sed -i '/\$(echo "\$os" | grub_quote)'\'' \${CLASS}/ s/'\'' \$/'\'' --unrestricted \$/' /etc/grub.d/10_linux
cat - <<EOM >> /etc/grub.d/40_custom
set superusers="root"
password_pbkdf2 root $GRUB_PASSWD
EOM

update-grub2

# Setup empty SSH authorized keys and passwordless sudo for ansible

mkdir -p ~ansible/.ssh
touch ~ansible/.ssh/authorized_keys
chown -R ansible.ansible ~ansible/.ssh

sed -i '/%sudo/ s/ALL$/NOPASSWD:ALL/' /etc/sudoers
echo "ioi ALL=NOPASSWD: /opt/ioi/bin/ioiconf.sh, /opt/ioi/bin/ioiexec.sh, /opt/ioi/bin/ioibackup.sh" >> /etc/sudoers.d/01-ioi
chmod 440 /etc/sudoers.d/01-ioi

# setup bash aliases for ansible user
cp /opt/ioi/misc/bash_aliases ~ansible/.bash_aliases
chmod 644 ~ansible/.bash_aliases
chown ansible.ansible ~ansible/.bash_aliases

# Documentation

apt -y install python3-doc

# CPP Reference

wget -O /tmp/html_book.zip https://github.com/PeterFeicht/cppreference-doc/releases/download/v20220730/html-book-20220730.zip
mkdir -p /usr/share/doc/cppreference
unzip -o /tmp/html_book.zip -d /usr/share/doc/cppreference
rm -f /tmp/html_book.zip

# Build logkeys

WORKDIR=`mktemp -d`
pushd $WORKDIR
git clone https://github.com/kernc/logkeys.git
cd logkeys
./autogen.sh
cd build
../configure
make
make install
# These SUID management scripts are not needed
rm /usr/local/bin/llk /usr/local/bin/llkk
cp ../keymaps/en_US_ubuntu_1204.map /opt/ioi/misc/
popd
rm -rf $WORKDIR

# Mark some packages as needed so they wont' get auto-removed

apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-image-`
apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-modules-`

# Remove unneeded packages

apt-mark auto gnome-power-manager brltty extra-cmake-modules
apt-mark auto llvm-13-dev zlib1g-dev libobjc-11-dev libx11-dev dpkg-dev manpages-dev
apt-mark auto linux-firmware memtest86+
apt-mark auto network-manager-openvpn network-manager-openvpn-gnome openvpn
apt-mark auto autoconf autotools-dev
#apt-mark -y auto `dpkg-query -Wf '${Package}\n' | grep linux-header`

# Remove most extra modules but preserve those for sound
#kernelver=$(uname -a | cut -d\  -f 3)
#tar jcf /tmp/sound-modules.tar.bz2 -C / \
#	lib/modules/$kernelver/kernel/sound/{ac97_bus.ko,pci} \
#	lib/modules/$kernelver/kernel/drivers/gpu/drm/vmwgfx
#apt -y remove `dpkg-query -Wf '${Package}\n' | grep linux-modules-extra-`
#tar jxf /tmp/sound-modules.tar.bz2 -C /
#depmod -a

# Create local HTML

cp -a html /usr/share/doc/ioi
mkdir -p /usr/share/doc/ioi/fonts
wget -O /tmp/fira-sans.zip "https://gwfh.mranftl.com/api/fonts/fira-sans?download=zip&subsets=latin&variants=regular"
wget -O /tmp/share.zip "https://gwfh.mranftl.com/api/fonts/share?download=zip&subsets=latin&variants=regular"
unzip -o /tmp/fira-sans.zip -d /usr/share/doc/ioi/fonts
unzip -o /tmp/share.zip -d /usr/share/doc/ioi/fonts
rm /tmp/fira-sans.zip
rm /tmp/share.zip

# Tinc Setup and Configuration

# Setup tinc skeleton config

mkdir -p /etc/tinc/vpn
mkdir -p /etc/tinc/vpn/hosts
cat - <<'EOM' > /etc/tinc/vpn/tinc-up
#!/bin/bash

source /opt/ioi/config.sh
ifconfig $INTERFACE "$(cat /etc/tinc/vpn/ip.conf)" netmask "$(cat /etc/tinc/vpn/mask.conf)"
route add -net $SUBNET gw "$(cat /etc/tinc/vpn/ip.conf)"
EOM
chmod 755 /etc/tinc/vpn/tinc-up
cp /etc/tinc/vpn/tinc-up /opt/ioi/misc/

cat - <<'EOM' > /etc/tinc/vpn/host-up
#!/bin/bash

source /opt/ioi/config.sh
logger -p local0.info TINC: VPN connection to $NODE $REMOTEADDRESS:$REMOTEPORT is up

# Force time resync as soon as VPN starts
systemctl restart systemd-timesyncd

# Fix up DNS resolution
resolvectl dns $INTERFACE $(cat /etc/tinc/vpn/dns.conf)
resolvectl domain $INTERFACE $DNS_DOMAIN
systemd-resolve --flush-cache

# Register something on our HTTP server to log connection
# XXX
EOM
chmod 755 /etc/tinc/vpn/host-up
cp /etc/tinc/vpn/host-up /opt/ioi/misc/

cat - <<'EOM' > /etc/tinc/vpn/host-down
#!/bin/bash

logger -p local0.info TINC: VPN connection to $NODE $REMOTEADDRESS:$REMOTEPORT is down
EOM
chmod 755 /etc/tinc/vpn/host-down

# Configure systemd for tinc
# XXX not for published VM
#systemctl enable tinc@vpn

systemctl disable multipathd

# Disable cloud-init
touch /etc/cloud/cloud-init.disabled

# At was not installed by default somewhy
apt -y install at

# Don't start atd service
systemctl disable atd

# Replace atd.service file
cat - <<EOM > /lib/systemd/system/atd.service
[Unit]
Description=Deferred execution scheduler
Documentation=man:atd(8)
After=remote-fs.target nss-user-lookup.target

[Service]
ExecStartPre=-find /var/spool/cron/atjobs -type f -name "=*" -not -newercc /run/systemd -delete
ExecStart=/usr/sbin/atd -f -l 5 -b 30
IgnoreSIGPIPE=false
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOM

chmod 644 /lib/systemd/system/atd.service

# Disable virtual consoles

cat - <<EOM >> /etc/systemd/logind.conf
NAutoVTs=0
ReserveVT=0
EOM

# Disable updates

cat - <<EOM > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOM

# Remove/clean up unneeded snaps

snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
	snap remove "$snapname" --revision="$revision"
done

# Mark g++ as explicitly needed

apt -y install g++

# Clean up apt

apt -y autoremove

# Remove desktop backgrounds
rm -rf /usr/share/backgrounds/*.jpg
rm -rf /usr/share/backgrounds/*.png

# Remove unwanted documentation
rm -rf /usr/share/doc/HTML
rm -rf /usr/share/doc/adwaita-icon-theme
rm -rf /usr/share/doc/alsa-base
rm -rf /usr/share/doc/cloud-init
rm -rf /usr/share/doc/cryptsetup
rm -rf /usr/share/doc/fonts-*
rm -rf /usr/share/doc/info
rm -rf /usr/share/doc/libgphoto2-6
rm -rf /usr/share/doc/libgtk*
rm -rf /usr/share/doc/libqt5*
rm -rf /usr/share/doc/libqtbase5*
rm -rf /usr/share/doc/man-db
rm -rf /usr/share/doc/manpages
rm -rf /usr/share/doc/openjdk-*
rm -rf /usr/share/doc/openssh-*
rm -rf /usr/share/doc/ppp
rm -rf /usr/share/doc/printer-*
rm -rf /usr/share/doc/qml-*
rm -rf /usr/share/doc/systemd
rm -rf /usr/share/doc/tinc
rm -rf /usr/share/doc/ubuntu-*
rm -rf /usr/share/doc/util-linux
rm -rf /usr/share/doc/wpasupplicant
rm -rf /usr/share/doc/x11*
rm -rf /usr/share/doc/xorg*
rm -rf /usr/share/doc/xproto
rm -rf /usr/share/doc/xserver*
rm -rf /usr/share/doc/xterm

# Create rc.local file
cp misc/rc.local /etc/rc.local
chmod 755 /etc/rc.local

# Set flag to run atrun.sh at first boot
touch /opt/ioi/misc/schedule2.txt.firstrun

# Embed version number
if [ -n "$VERSION" ] ; then
	echo "$VERSION" > /opt/ioi/misc/VERSION
fi

# Deny ioi user from SSH login
echo "DenyUsers ioi" >> /etc/ssh/sshd_config

echo "ansible:$ANSIBLE_PASSWD" | chpasswd

echo "### DONE ###"
echo "- Remember to run cleanup script."

# vim: ts=4
