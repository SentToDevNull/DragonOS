#!/bin/bash
#
# DragonOS
#
# MIT License
#
# Copyright (c) 2020 Lukas Yoder <lukas@lukasyoder.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

#------------------------------------------------------------------------#
#                                                                        #
#                             Preliminaries...                           #
#                                                                        #
#------------------------------------------------------------------------#

# log directory for logs of build progress for pausing and resuming work
mkdir -p sources/buildlogs
BLOGDIR=/sources/buildlogs

cd sources

#------------------------------------------------------------------------#
#                                                                        #
#                    Removing unnecessary components.                    #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/buildstagetwostrip1.txt ]; then
# strip everything
find /usr/lib -type f -name \*.a -exec strip --strip-debug {} ';'
# striping everything other than the libraries in /lib, because stripping
#   things that are in use is idiotic
find /usr/lib -type f -name \*.so*                                       \
  -exec strip --strip-unneeded {} ';'
find /{bin,sbin} /usr/{bin,sbin,libexec} -type f                         \
  -exec strip --strip-all {} ';'
# remove some vestigial static libs
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a
# clean up temp files from tests
rm -rf /tmp/*
# programs in /tools are no longer needed
rm -rf /tools/
touch $BLOGDIR/buildstagetwostrip1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                     Configuring system components.                     #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/buildstagetwoconfigure1.txt ]; then
# configuring DHCP
cat > /etc/systemd/network/10-eth0-dhcp.network << "EOF"
[Match]
Name=eth0
[Network]
DHCP=ipv4
[DHCP]
UseDomains=true
EOF
# use systemd-resolved; don't use if setting up network-manager
ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
# setting up hostname
echo "mashadar" > /etc/hostname
# create hosts file
cat > /etc/hosts << "EOF"
# Begin /etc/hosts
127.0.0.1 localhost
::1       localhost
# End /etc/hosts
EOF
# creating the inputrc file
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>
# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off
# Enable 8bit input
set meta-flag On
set input-meta On
# Turns off 8th bit stripping
set convert-meta Off
# Keep the 8th bit for display
set output-meta On
# none, visible or audible
set bell-style none
# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word
# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line
# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line
# End /etc/inputrc
EOF
# creating the shells file
cat > /etc/shells << "EOF"
# Begin /etc/shells
/bin/sh
/bin/bash
# End /etc/shells
EOF
# creating the fstab file
cat > /etc/fstab << "EOF"
# Begin /etc/fstab
# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sda1      /            ext4     defaults            1     1

# End /etc/fstab
EOF
touch $BLOGDIR/buildstagetwoconfigure1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                   Compile the target system's OPENSSL.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/openssl1.txt ]; then
rm -rf openssl*/
bash extract.sh openssl
cd openssl*/
./config --prefix=/usr                                                   \
         --openssldir=/etc/ssl                                           \
         --libdir=lib                                                    \
         shared                                                          \
         zlib-dynamic
make
# disable installing static libraries
sed -i 's# libcrypto.a##;s# libssl.a##;/INSTALL_LIBS/s#libcrypto.a##'    \
       Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl{,-1.1.0f}
cp -vfr doc/* /usr/share/doc/openssl-1.1.0f
cd ..
rm -rf openssl*/
touch $BLOGDIR/openssl1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Compile the target system's LINUX KERNEL.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/linuxkernel1.txt ]; then
rm -rf linux*/
bash extract.sh linux
cd linux*/
make mrproper
## copying over my kernel config file
cp -v /sources/kernelconfig.txt .config
##creating a config file yourself
#make menuconfig
make
make modules_install
cp -v arch/x86/boot/bzImage /boot/vmlinuz-systemd
cp -v System.map /boot/System.map
cp -v .config /boot/config
install -d /usr/share/doc/linux
cp -r Documentation/* /usr/share/doc/linux
install -v -m755 -d /etc/modprobe.d
# load USB modules in the correct order
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf
install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true
# End /etc/modprobe.d/usb.conf
EOF
cd ..
rm -rf linux*/
touch $BLOGDIR/linuxkernel1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                     Configuring system components.                     #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/buildstagetwoconfigure2.txt ]; then
# this file is required by systemd
#TODO: replace version number with a variable
cat > /etc/os-release << "EOF"
NAME="DragonOS"
VERSION="0.2.1"
ID=pos
PRETTY_NAME="DragonOS 0.2.1"
VERSION_CODENAME="Fledgeling"
EOF
# for LSB compliance
cat > /etc/lsb-release << "EOF"
DISTRIB_ID="DragonOS"
DISTRIB_RELEASE="0.2.1"
DISTRIB_CODENAME="Fledgeling"
DISTRIB_DESCRIPTION="DragonOS 0.2.1"
EOF
touch $BLOGDIR/buildstagetwoconfigure2.txt
fi
# set timezone to Eastern Standard Time
timedatectl set-timezone America/New_York
# setting keymap
cat > /etc/vconsole.conf << "EOF"
KEYMAP=dvorak
EOF
# setting locale
cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
LC_CTYPE=en_US
EOF
# setting the bash profile for non-login shells
cat > /root/.bashrc << "EOF"
PS1="[\u@\h \W]\\$ "
EOF
# setting the bash profile for login shells as well
cp /root/.bashrc /root/.bash_profile

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

# we need to keep the BLOGDIR in tact this time to copy over the finished
#   status through the driver script to the logs directory outside of the
#   chroot environment
touch $BLOGDIR/07-buildparttwo-finished.txt
