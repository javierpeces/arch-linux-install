:!/bin/bash
# bootinst.sh
# Before executing this script...
# - start the boot CD env
# - set a password for root
# - check network interface: "ip address"
# - start ssh server: "systemctl start sshd"

# ___________________________________________________________________
# set environment variables
#

source ./inclinst.sh

function setenviron( )
{
	echo "Set environment"

	### "es"
	### "es_ES.UTF-8"
	### "Lat2-Terminus16"
	### "es_ES.UTF-8 UTF-8"
	### "en_US.UTF-8 UTF-8"

	loadkeys ${keyboard}
	setfont ${consfont}
	sed -i -e 's/#${locale01}/${locale01}/' /etc/locale.gen
	sed -i -e 's/#${locale92}/${locale02}/' /etc/locale.gen
	locale-gen
	export LANG=${language}
}

# ___________________________________________________________________
# remove logical volumes, if any
#

function removelvm( )
{
	echo "Remove LVM objects"

	umount /mnt/opt/data
	umount /mnt/boot
	umount /mnt
	swapoff -a
	vgchange -an
	let i=1

	for name in root swap data
	do
		let volno=$((++ i))
		echo -e "\tRemove ${targethd}${volno}: vg${name} lv${name}"
		lvremove vg${name}/lv${name}
		vgremove vg${name}
		pvremove ${targethd}${volno}
	done
}

# ___________________________________________________________________
# wipe contents of target hard disk
#

function wipedisk( )
{
	echo "Create new disklabel"
	echo -e "o\nw" | fdisk ${targethd}

	echo "Wipe target hard disk"
	sfdisk ${targethd} <<- EOF 
	,0 
	,0 
	,0 
	,0 
	EOF

	partprobe ${targethd}
}

# ___________________________________________________________________
# partition target hard disk
#

function partition( )
{
	echo "Partition target disk"

	sfdisk ${targethd} <<- EOF
		2048,${bootsize},83,*
		,${rootsize},8e
		,${swapsize},8e
		,${datasize},8e
	EOF

	partprobe ${targethd}
}

# ___________________________________________________________________
# create target lvm structure
#

function createlvm( )
{
	echo "Create and activate LVM objects"

	let i=1

	for name in root swap data
	do
		let volno=$((++ i))
		echo -e "\tProcess ${targethd}${volno}: vg${name} lv${name}"
		pvcreate ${targethd}${volno}
		vgcreate vg${name} ${targethd}${volno}
		lvcreate -l 100%FREE -n lv${name} vg${name}
	done

	vgchange -ay
}

# ___________________________________________________________________
# 
#

function createfs( )
{
	echo "Create filesystems and swap space"

	for name in sda1 mapper/vgroot-lvroot mapper/vgdata-lvdata
	do
		echo -e "\tMake filesystem ${name}"
		mkfs -t ext4 /dev/${name}
	done

	echo -e "\tMake swap"
	mkswap /dev/mapper/vgswap-lvswap
}

# ___________________________________________________________________
# mount target filesystems and activate swap
#

function mountfs( )
{
	echo "Mount filesystems"

	echo -e "\tMount root"
	mount -t ext4 /dev/mapper/vgroot-lvroot /mnt

	echo -e "\tMount boot"
	mkdir /mnt/boot
	mount -t ext4 /dev/sda1 /mnt/boot

	echo -e "\tMount data"
	mkdir -p /mnt/opt/data
	mount -t ext4 /dev/mapper/vgdata-lvdata /mnt/opt/data

	echo -e "\tActivate swap"
	swapon /dev/mapper/vgswap-lvswap
}

# ___________________________________________________________________
# install base system in target fs
#

function installbase( )
{
	echo "Install base system in target root filesystem"
	echo -e "\n" | pacstrap -i /mnt base
}

# ___________________________________________________________________
# generate fstab entries 
#

function etcfstab( )
{
	echo "Generate fstab entries"
	genfstab -U -p /mnt > /mnt/etc/fstab
}

# ___________________________________________________________________
# post install
#

function postinst( )
{
	echo "Copying root script"
	cp ./rootinst.sh ./inclinst.sh /mnt/root/

	echo "Chrooting"
	arch-chroot /mnt /root/rootinst.sh

	echo "Unmounting filesystems"
	umount /mnt/opt/data
        umount /mnt/boot
        umount /mnt
        swapoff -a
	
	echo "Rebooting"
	# reboot
}

# ___________________________________________________________________
# the main loop
#

for routine in ${bootfunc}
do
	${routine}
	sleep 1
	echo "${routine} executed. Press [enter] or [control-c]"
	read
done

# setenviron
# removelvm
# wipedisk
# partition
# createlvm
# createfs
# mountfs
# changemirr
# installbase
# etcfstab
# postinst
