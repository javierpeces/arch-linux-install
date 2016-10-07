#!/bin/bash
# rootinst.sh -- the second stage
# 
# ___________________________________________________________________
# set environment variables
#

source ./inclinst.sh

# ___________________________________________________________________
# persistent keymap and console font
#

function setkmapfont( )
{
	echo "Setting keymap and font"
	echo "KEYMAP=${language}" > /etc/vconsole.conf
	echo "FONT=${consfont}" >> /etc/vconsole.conf
}

# ___________________________________________________________________
# timezone, clock, hostname, blacklisted modules
#

function settimeclock( )
{
	echo "Setting timezone and clock"

	# Europe/Madrid

	ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
	hwclock --systohc --utc

	echo "Setting hostname"
	echo "${hostname}" > /etc/hostname

	echo "Setup blacklist.conf"
	local modconf="/etc/modprobe.d/blacklist.conf"
	cat > ${modconf} <<- EOF
		blacklist floppy
		blacklist pcspkr
	EOF
}

# ___________________________________________________________________
# update initrd 
#

function updinitrd( )
{
	echo "Setup FILES in mkinitcpio.conf"
	local modconf="/etc/modprobe.d/blacklist.conf"
	local initconf="/etc/mkinitcpio.conf"
	cp ${initconf} ${initconf}-OLD
	sed -i -e "s_^FILES=\"*\"_FILES=\"$modconf\"_" ${initconf}

	echo "Setup HOOKS in mkinitcpio.conf"
	oldhooks="base udev autodetect modconf block filesystems keyboard fsck"
	newhooks="base udev autodetect modconf block lvm2 filesystems keyboard fsck"
	sed -i -e "s_^HOOKS=\"$oldhooks\"_HOOKS=\"$newhooks\"_" $initconf

	echo "Execute mkinitcpio"
	mkinitcpio -p linux
}

# ___________________________________________________________________
# install packages
#

function installpkgs( )
{
	echo "Updating package db"
	pacman-db-upgrade

	echo "Installing packages"
	pacsync ifplugd grub os-prober fuse mtools sudo openssh dhclient ntp
}

# ___________________________________________________________________
# execute grub
#

function execgrub( )
{
	echo "Running GRUB"
	grub-install --recheck ${targethd}
	grub-mkconfig -o /boot/grub/grub.cfg
}

# ___________________________________________________________________
# add users and set passwords
#

function userpass( )
{
	echo "Adding users and setting passwords"

	declare -a user=( ${admuser} ${cmsuser} ${reguser} )
	declare -a pass=( ${admpass} ${cmspass} ${regpass} )
	declare -a glst=( ${admlist} ${cmslist} ${reglist} )
	declare -a name=( 'System Admin' 'Content Admin' 'System User' )

	OLDIFS=$IFS
	IFS=$'\n'

	for i in 0 1 2
	do
		useradd -m -c "${name[$i]}" -s /bin/bash -G ${glst[$i]} ${user[$i]}
		echo "${user[$i]}:${pass[$i]}" | chpasswd
	done

	IFS=$OLDIFS
	echo "root:${rootpass}" | chpasswd
}

# ___________________________________________________________________
# enable sshd
#

function enablesshd( )
{
	echo "Install and enable sshd"
	pacsync openssh
	systemctl enable sshd
}

# ___________________________________________________________________
# install base development tools
#

function installdev( )
{
	echo "Install base dev tools"
	pacsync base-devel
}

# ___________________________________________________________________
# optional installation of graphical stuff
#

function instgraphic( )
{
	if [ "${xorg}" == "YES" ]
	then
		echo "Install something graphical, COBARDE"
		pacsync xorg-server xorg-server-utils xorg-xinit xorg-twm xorg-xclock xterm

		echo "Install fonts of your choice"
		pacsync ${xfonts}
	
		echo "Install input drivers of your choice"
		pacsync ${inputdrv}
	
		echo "Install the video driver of your choice"
		pacsync ${videodrv}

		if [ "${gnome}" == "YES" ]
		then
			echo "Install gnome if you are brave enough"
			pacsync gnome gnome-extra gdm gnome-tweak-tool gnome-terminal
		fi
	fi
}

# ___________________________________________________________________
# optional installation of netctl
#

function installnetctl( )
{
	if [ "${netctl}" == "YES" ]
	then
		echo "Install netctl if you want to"
		pacsync netctl
	fi
}

# ___________________________________________________________________
# optional installation of network-manager
#

function installnm( )
{
	if [ "${netman}" == "YES" ]
	then
		echo "Install NetworkManager if you want to"
		pacsync networkmanager networkmanager-openvpn 

		echo "Enable NetworkManager"
		systemctl enable NetworkManager	

		if [ "${xorg}" == "YES" ]
		then
			pacsync network-manager-applet
		fi
	fi
}

# ___________________________________________________________________
# setup netctl interface
#

function setupiface( )
{
	if [ "${netctl}" == "YES" -a "${netmode}" == "STATIC" ]
	then
		echo "Setup netctl (ethernet static)"
		ifacename
		local interface=${rv}
		cat > /etc/netctl/ethernet-static <<- EOF1
			Description='Static ethernet connection'
			Interface=${interface}
			Connection=ethernet
			IP=static
			Address=('${ipaddr}')
			Gateway='${gateway}'
			DNS=('${dns}')
			DNSDomain='${domain}'
			DNSSearch='${search}'
		EOF1
	fi
}

# ___________________________________________________________________
# setup bridge 
#

function setupbridge( )
{
	if [ "${netctl}" == "YES" -a "${netmode}" == "BRIDGE" ]
	then
		echo "Setup netctl (YEAH it's a bridge)"
		ifacename
		local interface=${rv}
		cat > /etc/netctl/bridge0 <<- EOF2
			Description="Bridge br0 connection"
			Interface=br0
			Connection=bridge
			BindsToInterfaces=(${interface})
			IP=static
			Address=('${ipaddr}')
			Gateway='${gateway}'
			DNS=('${dns}')
			DNSSearch="${search}"
		EOF2
	fi
}

# ___________________________________________________________________
# enable netctl
#

function enablenetctl( )
{
	echo "Enable network interface ${interface}"
	systemctl enable netctl

	if [ "${netctl}" == "YES" -a "${netmode}" == "STATIC" ]
	then
		netctl enable ethernet-static 
	fi

	if [ "${netctl}" == "YES" -a "${netmode}" == "BRIDGE" ]
	then
		netctl enable bridge0
	fi
}

# ___________________________________________________________________
# enablewheel
#

function enablewheel( )
{
	echo "Enable wheel as a 'sudoers' group"
	sed -i -e 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
}

# ___________________________________________________________________
# show what's next
#

function shownext( )
{
	echo "Exit the jail"
	echo "Unmount filesystems..."
	echo "- umount /mnt/opt/data"
	echo "- umount /mnt/boot"
	echo "- umount /mnt"
	echo "Ready for a reboot"
}

# ___________________________________________________________________
# the main loop
#

for routine in ${rootfuncs}
do
	${routine}
	sleep 1
	echo "${routine} executed. Press [enter] or [control-c]"
	read
done

# setenviron
# setkmapfont
# settimeclock
# updinitrd
# installpkgs
# execgrub
# userpass
# enablesshd
#
# instgraphic
# installnm
# setupiface
# setupbridge
# enablenetctl
# enablewheel
# shownext
