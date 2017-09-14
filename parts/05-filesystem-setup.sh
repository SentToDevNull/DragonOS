#!/bin/bash

#------------------------------------------------------------------------#
#                                                                        #
#              Allow 'root' to own the bootstrapping tools.              #
#                                                                        #
#------------------------------------------------------------------------#

chown -R root:root $LFS/tools

#------------------------------------------------------------------------#
#                                                                        #
#                Prepare the virtual kernel filesystems.                 #
#                                                                        #
#------------------------------------------------------------------------#

mkdir -pv $LFS/{dev,proc,sys,run}
# creating nodes for the console and null devices
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
# inheriting /dev directory from host; logical if we're building for the
#   host system
mount -v --bind /dev $LFS/dev
# now mounting the remaining virtual kernel filesystems
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch $WORDIR/logs/05-filesystem-setup-finished.txt
