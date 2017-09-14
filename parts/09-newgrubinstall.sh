#!/bin/bash

#------------------------------------------------------------------------#
#                                                                        #
#                             Preliminaries...                           #
#                                                                        #
#------------------------------------------------------------------------#

# log directory for logs of build progress for pausing and resuming work
mkdir -p sources/buildlogs
BLOGDIR=/sources/buildlogs

#------------------------------------------------------------------------#
#                                                                        #
#                Create a menu entry for our bootloader.                 #
#                                                                        #
#------------------------------------------------------------------------#

# install the grub configuration file to the correct directory; this
#   depends upon the directory where the host system installed grub to,
#   which is either '/boot/grub' or '/boot/grub2'; it varies by distro
# the quiet parameter prevents kernel messages from flooding the login
#   screen
if [ -d "/boot/grub2/" ]
then cat > /boot/grub2/grub.cfg << "EOF"
# Begin /boot/grub2/grub.cfg
set default=0
set timeout=5
insmod ext2
set root=(hd0,1)
menuentry "DragonOS 0.1.1" {
  linux /boot/vmlinuz-systemd root=/dev/sda1 ro quiet
}
EOF
else cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5
insmod ext2
set root=(hd0,1)
menuentry "DragonOS 0.1.1" {
  linux /boot/vmlinuz-systemd root=/dev/sda1 ro quiet
}
EOF
fi

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch $BLOGDIR/09-newgrubinstall-finished.txt
