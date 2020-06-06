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

# setting up the loopback device and recognize its partitions
losetup /dev/loop0 disk.img
partprobe /dev/loop0
# creating working directories
mkdir -p sys-old sys-new
# mounting the old disk at 'sys-old'
mount /dev/loop0p1 sys-old

# for determining what to resize the filesystem to; outputs space used in
#   GB (G), rounding up, and adds 1 to it
GBNEEDED=$(($(df -BG sys-old | awk '{if ($1 != "Filesystem") print $3}' |
              tr "G" " ") + 1))

#------------------------------------------------------------------------#
#                                                                        #
#          Setting up and populating the new disk with our OS.           #
#                                                                        #
#------------------------------------------------------------------------#

# create a new disk with enough disk space to hold the OS + GB of free
#   space
dd if=/dev/zero of=new-disk.img bs=1024k seek=$((GBNEEDED * 1024)) count=0
# make sure it's done being written to
sync
# set up a new loopback device with the new disk
losetup /dev/loop1 new-disk.img
# assigning the new disk a partition table
parted -s /dev/loop1 mklabel msdos
# creating a partition for the operating system, using the entire new disk
parted -s /dev/loop1 unit s mkpart primary ext2 -- 2048 -2
# make partition 1 of the new disk bootable
parted -s /dev/loop1 set 1 boot on
# assign a label to the new filesystem
mkfs.ext4 -L DragonOS /dev/loop1p1
# ensure all write operations are complete
sync
# mount the new disk at 'sys-new' and copy all files and permissions from
#   the old disk over to it
mount /dev/loop1p1 sys-new/
cp -rp sys-old/* sys-new/

#------------------------------------------------------------------------#
#                                                                        #
#                           Tying up loose ends.                         #
#                                                                        #
#------------------------------------------------------------------------#

# unmounting both disks
umount /dev/loop0p1
umount /dev/loop1p1
# removing the disks as loopback devices
losetup -d /dev/loop0
losetup -d /dev/loop1
# removing the working directories
rm -rf sys-old sys-new
# remove the old disk
rm -f disk.img
# ensure all write operations are complete
sync
# replacing the old disk with the new one
mv new-disk.img disk.img
# ensure all write operations are complete
sync


#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch logs/08-newdisk-finished.txt
