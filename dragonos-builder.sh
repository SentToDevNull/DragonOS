#!/bin/bash

##########################################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
#
#      .-._
#       \  '-._
#  ______/___  '.
# `'--.___  _\  /        DragonOS Builder, Version 0.2.1
#      /_.-' _\ \ _:,_
#    .'__ _.' \'-/,`-~`
#       '. ___.> /=,                                          ,  ,
#        / .-'/_ )                                           / \/ \
#        )'  ( /(/               by Lukas Yoder             (/ //_ \_
#             \\ "                                           \||  .  \
#              '=='                                    _,:__.-"/---\_ \
#                                                     '~-'--.)__( , )\ \
#                                                          ,'    \)|\ `\|
#                                                                " ||   (
#                                                                   /
VERSION=0.2.1
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
##########################################################################

#------------------------------------------------------------------------#
#                                                                        #
#                     Making all scripts executable...                   #
#                                                                        #
#------------------------------------------------------------------------#

chmod -R +x parts dragonos-builder.sh

#------------------------------------------------------------------------#
#                                                                        #
#                    Setting build system variables...                   #
#                                                                        #
#------------------------------------------------------------------------#

export LFS=$(pwd)/sysbuild
export WORDIR=`pwd`
THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)
export MAKEFLAGS="-j $THREADS"
export PLATFORM=$(bash parts/00-system-type-guesser.sh)
# by default, always start a new build
CONTINUESTATUS="true"

#------------------------------------------------------------------------#
#                                                                        #
#                    This script only works as root...                   #
#                                                                        #
#------------------------------------------------------------------------#

if [ "$EUID" -ne 0 ]
  then echo "Please run as root."
  exit
fi

#------------------------------------------------------------------------#
#                                                                        #
#                  Check for suitable build environment...               #
#                                                                        #
#------------------------------------------------------------------------#

function CHECKER {
time bash parts/01-checker.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#   Prepare build environment by making and mounting the disk as well    #
#     as downloading all packages and caching them for future builds.    #
#                                                                        #
#------------------------------------------------------------------------#

function PREPARE {
time bash parts/02-prepare.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#        Set up the unprivileged user "lfs" for a safer build...         #
#                                                                        #
#------------------------------------------------------------------------#

function SETUPLFS {
time bash parts/03-setup-lfs.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#        Set up a bootstrapped environment to build the system...        #
#                                                                        #
#------------------------------------------------------------------------#

function BOOTSTRAPSETUP {
cp parts/04-bootstrap-setup.sh $LFS
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources
cp parts/extract.sh $LFS/sources/
time su lfs -c /bin/bash << "EOF"
exec env HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' LFS=$LFS LC_ALL=POSIX      \
  LFS_TGT=$(uname -m)-lfs-linux-gnu PATH=/tools/bin:/bin:/usr/bin bash   \
  $LFS/04-bootstrap-setup.sh
EOF
rm -f $LFS/04-bootstrap-setup.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#       Set configuration variables and virtual kernel filesystems.      #
#                                                                        #
#------------------------------------------------------------------------#

function FILESYSTEMSETUP {
time bash parts/05-filesystem-setup.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#               Part One of the DragonOS system build...                 #
#                                                                        #
#------------------------------------------------------------------------#

function BUILDPARTONE {
cp parts/06-stage-one.sh $LFS
time chroot "$LFS" /tools/bin/env -i                                     \
  HOME=/root TERM="$TERM" PS1='\u:\w\$ ' LFS=$LFS MAKEFLAGS="$MAKEFLAGS" \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin                          \
  /tools/bin/bash +h -c "bash /06-stage-one.sh"
rm -f $LFS/06-stage-one.sh
# copying over finished status from chroot directory
cp $LFS/sources/buildlogs/06-buildpartone-finished.txt                   \
   logs/06-buildpartone-finished.txt
}

#------------------------------------------------------------------------#
#                                                                        #
#               Part Two of the DragonOS system build...                 #
#                                                                        #
#------------------------------------------------------------------------#

function BUILDPARTTWO {
cp parts/07-stage-two.sh $LFS
cp parts/kernelconfig.txt $LFS/sources/
time chroot "$LFS" /usr/bin/env -i HOME=/root TERM=$TERM PS1='\u:\w\$ '  \
  LFS=$LFS MAKEFLAGS="$MAKEFLAGS" PATH=/bin:/usr/bin:/sbin:/usr/sbin     \
  /bin/bash  +h -c "bash /07-stage-two.sh"
rm $LFS/07-stage-two.sh
# copying over finished status from chroot directory
cp $LFS/sources/buildlogs/07-buildparttwo-finished.txt                   \
   logs/07-buildparttwo-finished.txt
rm $LFS/sources/extract.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#                Finish setting up the DragonOS system...                #
#                                                                        #
#------------------------------------------------------------------------#

function FINALIZE {
# suppress errors
rm -rf $LFS/sources/
# unmount virtual filesystems
umount -l $LFS/dev/pts 2>/dev/null
umount -l $LFS/dev 2>/dev/null
umount -l $LFS/run 2>/dev/null
umount -l $LFS/proc 2>/dev/null
umount -l $LFS/sys 2>/dev/null
# unmount LFS itself
umount -l /dev/loop0p1 2>/dev/null
losetup -d /dev/loop0 2>/dev/null
partprobe
userdel lfs 2>/dev/null
rm -rf /home/lfs/
rm -rf $LFS
# show completion status of this step
touch logs/finalize-finished.txt
}

#------------------------------------------------------------------------#
#                                                                        #
#   Copy system over to a smaller disk (to make more redistributable).   #
#                                                                        #
#------------------------------------------------------------------------#

function NEWDISK {
set -x
time bash parts/08-newdisk.sh
}

#------------------------------------------------------------------------#
#                                                                        #
#              Set up the GRUB2 bootloader on the new disk.              #
#                                                                        #
#------------------------------------------------------------------------#

function NEWGRUBINSTALL {
mkdir -p $LFS
losetup /dev/loop0 disk.img
partprobe /dev/loop0
umount $LFS 2>/dev/null
mount /dev/loop0p1 $LFS
rm -f $LFS/09-newgrubinstall.sh
if [ -z $(which grub-install 2>/dev/null) ]
  then grub2-install --target i386-pc --boot-directory $LFS/boot/        \
                     /dev/loop0
  else grub-install --target i386-pc --boot-directory $LFS/boot/         \
                     /dev/loop0
fi
cp parts/09-newgrubinstall.sh $LFS
time chroot "$LFS" /usr/bin/env -i HOME=/root TERM=$TERM                 \
  PS1='\u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/bash << "EOF"
bash /09-newgrubinstall.sh
EOF
# removing the newgrubinstall script
rm -rf $LFS/09-newgrubinstall.sh

# copying over finished status from chroot directory
mv $LFS/sources/buildlogs/09-newgrubinstall-finished.txt                 \
   logs/09-newgrubinstall-finished.txt

# remove the sources from the image
rm -rf $LFS/sources/

# unmount the image and destroy the loopback device
umount /dev/loop0p1
losetup -d /dev/loop0

}

#------------------------------------------------------------------------#
#                                                                        #
#  Optional Command: Resets the build process but keeps package caches.  #
#                                                                        #
#------------------------------------------------------------------------#

if [ "$1" == "restart" ]
  then FINALIZE
  cd $WORDIR
  rm -f disk.img
  rm -rf logs
  rm -rf cache/meta/
  exit
fi

#------------------------------------------------------------------------#
#                                                                        #
# Optional Command: Clears all build material, including package caches. #
#                                                                        #
#------------------------------------------------------------------------#

if [ "$1" == "clean" ]
  then FINALIZE  2> /dev/null
  cd $WORDIR
  rm -f disk.img
  rm -rf logs
  rm -rf cache
  exit
fi

#------------------------------------------------------------------------#
#                                                                        #
#  Optional Command: Compresses free space to facilitate redistirbution. #
#                                                                        #
#------------------------------------------------------------------------#

if [ "$1" == "dist" ]
  then xz -z9 -e -k -C sha256 disk.img &
  progress -m
  exit
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Optional Command: Continues an existing build.             #
#                                                                        #
#------------------------------------------------------------------------#

if [ "$1" == "continue" ]
  then CONTINUESTATUS="true"
fi

#------------------------------------------------------------------------#
#                                                                        #
#     Checks to see if build is possible and exits the script if not.    #
#                                                                        #
#------------------------------------------------------------------------#

# creates a log directory for all subsequent log files
mkdir -p logs && chmod -R 777 logs
# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/01-checker-finished.txt
fi
# checks whether system dependencies are met; skips if already done
if [ ! -f logs/01-checker-finished.txt ]; then
CHECKER 2>&1 | tee logs/01-checker-output.txt
fi
# stops script if dependencies are not met
if [ ! -f logs/01-checker-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#  Sets up the target filesystem and source tarballs. Exits the script   #
#    upon encountering any errors.                                       #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/02-prepare-finished.txt
fi
# sets up filesystem and source tarballs; skips if already done
if [ ! -f logs/02-prepare-finished.txt ]; then
PREPARE 2>&1 | tee logs/02-prepare-output.txt
fi
# stops script if filesystem creation had errors
if [ ! -f logs/02-prepare-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#   Sets up the 'lfs' user, who owns the sources and tools directories.  #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/03-setup-lfs-finished.txt
fi
# sets up the unprivileged 'lfs' user with ownership of tools and sources;
#   skips if finished
if [ ! -f logs/03-setup-lfs-finished.txt ]; then
SETUPLFS 2>&1 | tee logs/03-setuplfs-output.txt
fi
# stops the script if the unprivileged user setup had errors
if [ ! -f logs/03-setup-lfs-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#    Builds the bootstrapping system used to build the target system.    #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/04-bootstrap-setup-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/04-bootstrap-setup-finished.txt ]; then
BOOTSTRAPSETUP 2>&1 | tee logs/04-bootstrapsetup-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/04-bootstrap-setup-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#                Set up the target system's filesystem.                  #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/05-filesystem-setup-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/05-filesystem-setup-finished.txt ]; then
FILESYSTEMSETUP 2>&1 | tee logs/05-filesystemsetup-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/05-filesystem-setup-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#          Build the target system libraries and executables.            #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/06-buildpartone-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/06-buildpartone-finished.txt ]; then
BUILDPARTONE 2>&1 | tee logs/06-buildpartone-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/06-buildpartone-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#           Build the target system kernel and config files.             #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/07-buildparttwo-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/07-buildparttwo-finished.txt ]; then
BUILDPARTTWO 2>&1 | tee logs/07-buildparttwo-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/07-buildparttwo-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#                  Finalizing the target system build.                   #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/finalize-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/finalize-finished.txt ]; then
FINALIZE 2>&1 | tee logs/finalize-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/finalize-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#               Set up a new, smaller disk and filesystem.               #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/08-newdisk-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/08-newdisk-finished.txt ]; then
NEWDISK 2>&1 | tee logs/08-newdisk-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/08-newdisk-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#                      Install GRUB to the new disk.                     #
#                                                                        #
#------------------------------------------------------------------------#

# cleans previous checker status if not continuing
if [ $CONTINUESTATUS == "false" ]
  then rm -f logs/09-newgrubinstall-finished.txt
fi
# sets up the bootstrapping system; skips if finished
if [ ! -f logs/09-newgrubinstall-finished.txt ]; then
NEWGRUBINSTALL 2>&1 | tee logs/09-newgrubinstall-output.txt
fi
# stops the script if the bootstrapping system was not successfully built
if [ ! -f logs/09-newgrubinstall-finished.txt ]; then exit 1; fi

#------------------------------------------------------------------------#
#                                                                        #
#         If the build process reached this point, it's complete.        #
#                                                                        #
#------------------------------------------------------------------------#

echo -e "\nCongrats on your new DragonOS build!"
