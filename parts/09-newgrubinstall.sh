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
  linux /boot/vmlinuz-systemd root=/dev/sda1 ro quiet rootfstype=ext4
}
EOF
else cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5
insmod ext2
set root=(hd0,1)
menuentry "DragonOS 0.1.1" {
  linux /boot/vmlinuz-systemd root=/dev/sda1 ro quiet rootfstype=ext4
}
EOF
fi

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch $BLOGDIR/09-newgrubinstall-finished.txt
