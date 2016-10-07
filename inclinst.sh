#!/bin/bash
#
# inclinst -- sourced by arch autoinstall scripts
#
# target hard disk
#

targethd="/dev/sda"

#
# locale and font information
#

keyboard="es"
language="es_ES.UTF-8"
consfont="Lat2-Terminus16"
locale01="es_ES.UTF-8 UTF-8"
locale02="en_US.UTF-8 UTF-8"

#
# partition schema
# sizes in sectors; 1 sector = 512 bytes
#
# boot ... 600 MB * 1024 * 2 = 1228800
# root ... 8 GB * 1024 * 1024 * 2 = 16777216
# swap ... 2 GB * 1024 * 1024 * 2 = 4194304
# data ... blank uses the rest of the disk
#
# ,1228800,83,*
# ,12288000,8e
# ,4096000,8e
# ,,8e
#

bootsize="1228800"
rootsize="16777216"
swapsize="4194304"
datasize=""

#
# preferred servers
#

server01="http://osl.ugr.es/archlinux/\$repo/os/\$arch"
server02="http://sunsite.rediris.es/mirror/archlinux/\$repo/os/\$arch"

#
# timezone
#

timezone="Europe/Madrid"

#
# hostname
#

hostname="hostarch"

#
# local users
# - administrator
# - content user
# - non privileged user
# - CHANGE ALL PASSWORDS ASAP
# 

admuser="sysadmin"
admpass="YOUR-SYS-PASS-HERE"
admlist="wheel,optical,audio,video"

cmsuser="cmsadmin"
cmspass="YOUR-CMS-PASS-HERE"
cmslist="optical,audio,video"

reguser="sysuser"
regpass="YOUR-USER-PASS-HERE"
reglist="optical,audio,video"

rootpass="YOUR-ROOT-PASS-HERE"

# ___________________________________________________________________
# graphical environment
# - xf86-video-ati
# - xf86-video-amdgpu
# - xf86-video-intel
# - nvidia nvidia-utils
#

xorg="NO"
gnome="NO"
videodrv="xf86-video-vmware"
inputdrv="xf86-input-synaptics xf86-input-mouse xf86-input-keyboard"
xfonts="ttf-dejavu ttf-droid ttf-inconsolata otf-fira-mono otf-fira-sans"

# ___________________________________________________________________
# network data
#

netctl="YES"
netmode="STATIC"
netman="NO"
ipaddr="192.168.1.240/24"
gateway="192.168.1.1"
dns="192.168.1.100"
domain="test.lab"
search="test.lab cloud.local"

# ___________________________________________________________________
# DON'T MODIFY BEYOND THIS POINT UNLESS YOU KNOW WHAT YOU DO
# ___________________________________________________________________
# set environment
#
# "es"
# "es_ES.UTF-8"
# "Lat2-Terminus16"
# "es_ES.UTF-8 UTF-8"
# "en_US.UTF-8 UTF-8"


function setenviron( )
{
        echo "Set environment"

        loadkeys ${keyboard}
        setfont ${consfont}
        sed -i -e 's/#${locale01}/${locale01}/' /etc/locale.gen
        sed -i -e 's/#${locale02}/${locale02}/' /etc/locale.gen
        locale-gen
        export LANG=${language}
}

# ___________________________________________________________________
# change mirror
#

function changemirror( )
{
        echo "Change mirrorlist"

        local mirrfile="/etc/pacman.d/mirrorlist"

        mv ${mirrfile} ${mirrfile}.OLD
        cat <<- EOF > ${mirrfile}
                Server = ${server01}
                Server = ${server02}
        EOF
}

# ___________________________________________________________________
# run pacman without confirmation
#

function pacsync( )
{
        echo -e "\n" | pacman -S --needed $*
}

# ___________________________________________________________________
# guess interface name
#

function ifacename( )
{
        local netcf="/proc/sys/net/ipv4/conf/*"
        local netif=`ls -1d ${netcf} | awk -F/ '{print $7}'|egrep -v "all|default|lo"`
        rv=${netif}
}

# ___________________________________________________________________
# selected boot functions 
#

bootfuncs="setenviron removelvm wipedisk partition createlvm createfs mountfs \
	changemirror installbase etcfstab postinst"

# ___________________________________________________________________
# selected root functions 
#

rootfuncs="setenviron setkmapfont settimeclock updinitrd \
        changemirror installpkgs execgrub userpass enablesshd installdev \
	instgraphic installnetctl setupiface setupbridge \
        enablenetctl enablewheel shownext"

#
# END OF IT ALL
#
