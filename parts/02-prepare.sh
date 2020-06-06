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
#        Terminate if any component exits with a non-zero status.        #
#                                                                        #
#------------------------------------------------------------------------#

set -e

#------------------------------------------------------------------------#
#                                                                        #
# Create a disk image with a bootable ext4 partition, with space for MBR.#
#                                                                        #
#------------------------------------------------------------------------#

# create blank raw disk image (25GB); seek value is 25GB * 1024
dd if=/dev/zero of=disk.img bs=1024k seek=25600 count=0 && sync
# detach all loop devices
losetup -D
# attach 'disk.img' to '/dev/loop0'
losetup /dev/loop0 disk.img
# write the msdos partition table
parted -s /dev/loop0 mklabel msdos
# write from sector 2048 to the end of the disk
parted -s /dev/loop0 unit s mkpart primary ext2 -- 2048 -2
# make the partition bootable
parted -s /dev/loop0 set 1 boot on
# create the ext4 filesystem named 'DragonOS' on partition 1
mkfs.ext4 -L DragonOS /dev/loop0p1

#------------------------------------------------------------------------#
#                                                                        #
#    Make the loopback device's mount point and mount the partition.     #
#                                                                        #
#------------------------------------------------------------------------#

# make a place to build the new system; this directory will be the mount
#   point for the new operating system's partition
export LFS=$(pwd)/sysbuild
echo $LFS
mkdir -p $LFS
# now mount the new filesystem at the aforementioned mount point
mount -t ext4 /dev/loop0p1 $LFS

#------------------------------------------------------------------------#
#                                                                        #
# Download packages, cache them, and copy them to the sources directory. #
#                                                                        #
#------------------------------------------------------------------------#

# making and entering package cache directory
mkdir -p cache/meta/changes.d/
cp -r parts/packagemods/* cache/meta/changes.d/
mkdir -p cache/meta/changes.d/{replacements,additions,patches}
cd cache
# make sure the package list exists and download it if not
if [ ! -f meta/package-list ]; then
  wget http://www.linuxfromscratch.org/lfs/downloads/8.1-systemd/wget-list \
       -O meta/package-list
fi

# adding package replacements to the package set
IFS=$'\n'
for f in $(find meta/changes.d/replacements/ -type f); do
  PKG_REGEX=$(cat "$f" | head -n3 | tail -n1)
  PKG_URL=$(cat "$f" | head -n7 | tail -n1 | sed "s,\:,\\\:,g" |
            sed "s,\/,\\\\\/,g" | sed "s,\.,\\\.,g" | sed "s,\-,\\\-,g")
  sed -i "s,$PKG_REGEX,$PKG_URL,g" meta/package-list
done
unset IFS PKG_REGEX PKG_URL

# adding package additions to the package set
IFS=$'\n'
for f in $(find meta/changes.d/additions/ -type f); do
  echo "$f"
  PKG_URL=$(cat "$f" | head -n3 | tail -n1)
  echo $PKG_URL >> meta/package-list
done
unset IFS PKG_URL

# make sure packages are saved in the cache and download them if not
IFS=$'\n'
for file in $(cat meta/package-list | sed "s/\(.*\)\///g")
do
  if [ ! -f $file ]; then
    wget $(grep $file meta/package-list)
  fi
done
unset IFS

# make sure the package checksum list is present and download it if not
if [ ! -f meta/md5sums ]; then
  wget http://www.linuxfromscratch.org/lfs/view/8.1-systemd/md5sums   \
       -O meta/md5sums
fi

# adding package replacements to the package checksum set
IFS=$'\n'
for f in $(find meta/changes.d/replacements/ -type f); do

  PKG_REGEX=$(cat "$f" | head -n3 | tail -n1)
  PKG_MD5=$(cat "$f" | head -n11 | tail -n1 | sed "s,\:,\\\:,g" |
            sed "s,\/,\\\\\/,g" | sed "s,\.,\\\.,g" | sed "s,\-,\\\-,g")
  sed -i "s,$PKG_REGEX,$PKG_MD5,g" meta/md5sums

done
unset IFS PKG_REGEX PKG_MD5

# adding package additions to the package checksum set
IFS=$'\n'
for f in $(find meta/changes.d/additions/ -type f); do

  PKG_MD5=$(cat "$f" | head -n7 | tail -n1)
  echo $PKG_MD5 >> meta/md5sums

done
unset IFS PKG_MD5

# check md5sums and keep redownloading packages until none are corrupt
while [ ! -z "$(md5sum -c meta/md5sums --quiet 2>/dev/null |
                sed "s/:\(.*\)//g")" ]; do
  IFS=$'\n'
  for file in $(md5sum -c meta/md5sums --quiet 2>/dev/null |
                sed "s/:\(.*\)//g"); do
    rm -f $file
    wget $(grep $file meta/package-list)
  done
  unset IFS
done

# downloading patches and check patch checksums
IFS=$'\n'
for f in $(find meta/changes.d/patches/ -type f); do

  echo "$f"
  PATCH_URL=$(cat "$f" | head -n3 | tail -n1)
  wget $PATCH_URL
  PATCH_MD5=$(cat "$f" | head -n7 | tail -n1)
  echo $PATCH_MD5 >> meta/patch-md5sums
  # while patch doesn't match checksum, redownload
  while [ ! -z "$(md5sum -c meta/patch-md5sums --quiet 2>/dev/null |
                sed "s/:\(.*\)//g")" ]; do
    IFS=$'\n'
    for file in $(md5sum -c meta/patch-md5sums --quiet 2>/dev/null |
                sed "s/:\(.*\)//g"); do
      rm -f $file
      wget $PATCH_URL
    done
  done
  # ends checksum checker
  PATCH_OLDNAME=$(cat "$f" | head -n7 | tail -n1 | sed "s/\(.*\) //g")
  PATCH_NEWNAME=$(cat "$f" | head -n11 | tail -n1)
  if [ $(wc -l "$f" | sed "s, \(.*\),,g") == 15 ]; then
    eval $(cat "$f" | head -n15 | tail -n1)
  fi

done
unset IFS PATCH_URL PATCH_MD5 PATCH_OLDNAME PATCH_NEWNAME

# exit the package cache directory
cd ..

# create directory to unpack sources, build them, and store tarballs and
#   patches
mkdir -p $LFS/sources

# make the sources directory sticky so that out of all users who have
#   write permissions to the directory, only the owner of a file can
#   delete it
chmod a+wt $LFS/sources

# copy all packages and patches over to the new system's sources directory
cp -r cache/* $LFS/sources

#------------------------------------------------------------------------#
#                                                                        #
# Create a tools directory for the bootstrapping tools, and make it look #
#   the same on the target system as on the host by creating the '/tools'#
#   symlink on the host system.                                          #
#                                                                        #
#------------------------------------------------------------------------#

# make a separate directory for tools needed to bootstrap the system
mkdir -p $LFS/tools

# create a symlink to tools; this makes /tools point to sysbuild/tools
ln -sf $LFS/tools /

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch logs/02-prepare-finished.txt
