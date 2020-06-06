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

# use ANSI escape codes to colorize output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# log directory for logs of build progress for pausing and resuming work
mkdir -p sources/buildlogs
BLOGDIR=/sources/buildlogs

cd sources

#------------------------------------------------------------------------#
#                                                                        #
#                     Creating filesystem directories.                   #
#                                                                        #
#------------------------------------------------------------------------#

mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv  /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv  /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}
case $(uname -m) in
 x86_64) mkdir -pv /lib64 ;;
esac
mkdir -pv /var/{log,mail,spool}
ln -fsv /run /var/run
ln -fsv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

#------------------------------------------------------------------------#
#                                                                        #
#   Symlinking target system tools to bootstrapping tools for now. The   #
#     symlinks will be replaced when the actual tools are built.         #
#                                                                        #
#------------------------------------------------------------------------#

ln -fsv /tools/bin/{bash,cat,echo,pwd,stty} /bin
ln -fsv /tools/bin/perl /usr/bin
ln -fsv /tools/lib/libgcc_s.so{,.1} /usr/lib
ln -fsv /tools/lib/libstdc++.so{,.6} /usr/lib
sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la
ln -fsv bash /bin/sh

#------------------------------------------------------------------------#
#                                                                        #
#   List mounted file systems in /etc/mtab for backwards-compatibility.  #
#                                                                        #
#------------------------------------------------------------------------#

ln -fsv /proc/self/mounts /etc/mtab

#------------------------------------------------------------------------#
#                                                                        #
#         Creating common user accounts for admins and services.         #
#                                                                        #
#------------------------------------------------------------------------#

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

#------------------------------------------------------------------------#
#                                                                        #
#    Creating common groups for admins and systemd services to satisfy   #
#      udev requirements.                                                #
#                                                                        #
#------------------------------------------------------------------------#

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
nogroup:x:99:
users:x:999:
EOF

#------------------------------------------------------------------------#
#                                                                        #
#    Creating log files because if not present, many programs will not   #
#      create them and therefore will not store logs.                    #
#                                                                        #
#------------------------------------------------------------------------#

# the /var/log/wtmp file records all logins and logouts
# the /var/log/lastlog file records when each user last logged in
# the /var/log/faillog file records failed login attempts
# the /var/log/btmp file records the bad login attempts
touch /var/log/{btmp,lastlog,faillog,wtmp}
# the /run/utmp file records the users that are currently logged in; this
#   file is created dynamically in the boot scripts, so we won't create it
#   manually
chgrp -v utmp /var/log/lastlog
# tuning permissions for some logs
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

#------------------------------------------------------------------------#
#                                                                        #
#           Unpack the target version of LINUX KERNEL headers.           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/kernelheaders1.txt ]; then
rm -rf linux*/
bash extract.sh linux
cd linux*/
make mrproper
make INSTALL_HDR_PATH=dest headers_install
find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* /usr/include
cd ..
rm -rf linux*/
touch $BLOGDIR/kernelheaders1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                    Installing the MAN PAGE system.                     #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/manpages1.txt ]; then
rm -rf man-pages*/
bash extract.sh man-pages
cd man-pages*/
make install
cd ..
rm -rf man-pages*/
touch $BLOGDIR/manpages1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GLIBC.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/glibc1.txt ]; then
rm -rf glibc*/
bash extract.sh glibc
cd glibc*/
# applying patch
#TODO: replace "2.26" with glob pattern
patch -Np1 -i ../glibc-2.26-fhs-1.patch
# making a symlink for LSB compliance and a compatibility symlink for
#   x86_64
case $(uname -m) in
  x86) ln -fs ld-linux.so.2 /lib/ld-lsb.so.3
  ;;
  x86_64) ln -fs ../lib/ld-linux-x86-64.so.2 /lib64
          ln -fs ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
  ;;
esac
mkdir build && cd build
../configure --prefix=/usr                                               \
             --enable-kernel=3.2                                         \
             --enable-obsolete-rpc                                       \
             --enable-stack-protector=strong                             \
             libc_cv_slibdir=/lib
make
touch /etc/ld.so.conf
make install
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
install -v -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -v -Dm644 ../nscd/nscd.service /lib/systemd/system/nscd.service
# install locales for tests
mkdir -pv /usr/lib/locale
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
## actually install all locales
#make localedata/install-locales

#     ---     ---     ---    ---   ----   ---    ---     ---     ---     #
# ---     ---     ---     ---   ---    ---   ---     ---     ---     --- #
#     ---     ---     ---    Configuring GLIBC   ---     ---     ---     #
# ---     ---     ---     ---   ---    ---   ---     ---     ---     --- #
#     ---     ---     ---    ---   ----   ---    ---     ---     ---     #

# create /etc/nsswitch.conf file because Glibc defaults do not work well
#   in a networked environment
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
# End /etc/nsswitch.conf
EOF
# set up time zone data
#TODO: replace "tzdata2017b" with a glob pattern
#tar -xf ../../tzdata2017b.tar.gz
bash extract.sh tzdata2017b
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica    \
          asia australasia backward pacificnew systemv; do
    zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
    zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -fsv /usr/share/zoneinfo/America/New_York /etc/localtime
# adding library paths for the dynamic loader to use
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
mkdir -pv /etc/ld.so.conf.d #include contents of directories
cd ../..
rm -rf glibc*/
touch $BLOGDIR/glibc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#     Ensure than newly-compiled programs link against the new system.   #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/ensurebuild.txt ]; then
# link all newly-compiled programs against our new system libraries
mv -fv /tools/bin/{ld,ld-old}
mv -fv /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -fv /tools/bin/{ld-new,ld}
ln -fsv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
# point the GCC specs file to the dynamic linker
gcc -dumpspecs | sed -e 's@/tools@@g'                                    \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}'                  \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >                       \
    `dirname $(gcc --print-libgcc-file-name)`/specs
touch $BLOGDIR/ensurebuild.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                           Installing ZLIB.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/zlib1.txt ]; then
rm -rf zlib*/
bash extract.sh zlib
cd zlib*/
./configure --prefix=/usr
make
make install
mv -v /usr/lib/libz.so.* /lib
ln -fsv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
cd ..
rm -rf zlib*/
touch $BLOGDIR/zlib1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing FILE.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/file1.txt ]; then
rm -rf file*/
bash extract.sh file
cd file*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf file*/
touch $BLOGDIR/file1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing READLINE.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/readline1.txt ]; then
rm -rf readline*/
bash extract.sh readline
cd readline*/
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
#TODO: replace "7.0" with glob pattern
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --docdir=/usr/share/doc/readline-7.0
make SHLIB_LIBS=-lncurses
make SHLIB_LIBS=-lncurses install
mv -v /usr/lib/lib{readline,history}.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so)                    \
        /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so )                    \
        /usr/lib/libhistory.so
# for documentation
#TODO: replace "7.0" with glob pattern
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-7.0
cd ..
rm -rf readline*/
touch $BLOGDIR/readline1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing M4.                              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/mfour1.txt ]; then
rm -rf m4*/
bash extract.sh m4
cd m4*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf m4*/
touch $BLOGDIR/mfour1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing BC.                              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bc1.txt ]; then
rm -rf bc*/
bash extract.sh bc
cd bc*/
cat > bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1 s/^/{"/'                                                       \
    -e 's/$/",/'                                                         \
    -e '2,$ s/^/"/'                                                      \
    -e '$ d'                                                             \
    -i libmath.h
sed -e '$ s/$/0}/'                                                       \
    -i libmath.h
EOF
#TODO: replace the "6" with a glob pattern
ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
ln -sfv libncurses.so.6 /usr/lib/libncurses.so
#fix an error in configure due to missing files early on
sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure
./configure --prefix=/usr                                                \
            --with-readline                                              \
            --mandir=/usr/share/man                                      \
            --infodir=/usr/share/info
make
make install
cd ..
rm -rf bc*/
touch $BLOGDIR/bc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing BINUTILS.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/binutils1.txt ]; then
rm -rf binutils*/
bash extract.sh binutils
cd binutils*/
mkdir build && cd build
../configure --prefix=/usr                                               \
             --enable-gold                                               \
             --enable-ld=default                                         \
             --enable-plugins                                            \
             --enable-shared                                             \
             --disable-werror                                            \
             --with-system-zlib
make tooldir=/usr
make tooldir=/usr install
cd ../..
rm -rf binutils*/
touch $BLOGDIR/binutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GMP.                              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gmp1.txt ]; then
rm -rf gmp*/
bash extract.sh gmp
cd gmp*/
#TODO: replace "gmp-6.1.2" with glob pattern
./configure --prefix=/usr                                                \
            --enable-cxx                                                 \
            --disable-static                                             \
            --docdir=/usr/share/doc/gmp-6.1.2
make
make html
make install
make install-html
cd ..
rm -rf gmp*/
touch $BLOGDIR/gmp1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing MPFR.                              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/mpfr1.txt ]; then
rm -rf mpfr*/
bash extract.sh mpfr
cd mpfr*/
#TODO: replace "mpfr-3.1.5" with glob pattern
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --enable-thread-safe                                         \
            --docdir=/usr/share/doc/mpfr-3.1.5
make
make html
make install
make install-html
cd ..
rm -rf mpfr*/
touch $BLOGDIR/mpfr1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing MPC.                              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/mpc1.txt ]; then
rm -rf mpc*/
bash extract.sh mpc
cd mpc*/
#TODO: replace "mpc-1.0.3" with glob pattern
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --docdir=/usr/share/doc/mpc-1.0.3
make
make html
make install
make install-html
cd ..
rm -rf mpc*/
touch $BLOGDIR/mpc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#            Installing GCC and ensuring it works properly.              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gcc1.txt ]; then
rm -rf gcc*/
bash extract.sh gcc
cd gcc*/
# changes default directory name for 64-bit libraries to lib from lib64
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
mkdir build && cd build
SED=sed                                                                  \
../configure --prefix=/usr                                               \
             --enable-languages=c,c++                                    \
             --disable-multilib                                          \
             --disable-bootstrap                                         \
             --with-system-zlib
make
make install
ln -fsv ../usr/bin/cpp /lib
ln -fsv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
#TODO: replace "7.2.0" with glob pattern
ln -fsv ../../libexec/gcc/$(gcc -dumpmachine)/7.2.0/liblto_plugin.so     \
        /usr/lib/bfd-plugins/
# correcting a misplaced file
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd ../..
rm -rf gcc*/
touch $BLOGDIR/gcc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing BZIP2.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bziptwo1.txt ]; then
rm -rf bzip2*/
bash extract.sh bzip2
cd bzip2*/
# documentation patch
#TODO: replace "1.0.6" with glob pattern
patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
# for relative symlinks
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
# for man pages
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
# create necessary symlinks
cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -fsv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -fsv bzip2 /bin/bunzip2
ln -fsv bzip2 /bin/bzcat
cd ..
rm -rf bzip2*/
touch $BLOGDIR/bziptwo1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                        Installing PKG-CONFIG.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/pkg-config1.txt ]; then
rm -rf pkg-config*/
bash extract.sh pkg-config
cd pkg-config*/
#TODO: replace "0.29.2" with glob pattern
./configure --prefix=/usr                                                \
            --with-internal-glib                                         \
            --disable-compile-warnings                                   \
            --disable-host-tool                                          \
            --docdir=/usr/share/doc/pkg-config-0.29.2
make
make install
cd ..
rm -rf pkg-config*/
touch $BLOGDIR/pkg-config1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing NCURSES.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/ncurses1.txt ]; then
rm -rf ncurses*/
bash extract.sh ncurses
cd ncurses*/
# no unnecessary static libs
sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
./configure --prefix=/usr                                                \
            --mandir=/usr/share/man                                      \
            --with-shared                                                \
            --without-debug                                              \
            --without-normal                                             \
            --enable-pc-files                                            \
            --enable-widec
make
make install
# moving shared libraries to the /lib directory
#TODO: perhaps place glob pattern earlier by removing the "6"
mv -v /usr/lib/libncursesw.so.6* /lib
# recreate symlinks after moving
ln -fsv ../../lib/$(readlink /usr/lib/libncursesw.so)                    \
        /usr/lib/libncursesw.so
# some fixes
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -fsv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
# ensure old applications looking for -lcurses are still buildable
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -fsv libncurses.so      /usr/lib/libcurses.so
# install ncurses documentation
#TODO: replace "6.0" with glob pattern
mkdir -v       /usr/share/doc/ncurses-6.0
cp -v -R doc/* /usr/share/doc/ncurses-6.0
# to include non-wide-character libraries
make distclean
./configure --prefix=/usr                                                \
            --with-shared                                                \
            --without-normal                                             \
            --without-debug                                              \
            --without-cxx-binding                                        \
            --with-abi-version=5
make sources libs
#TODO: perhaps place glob pattern earlier by removing the 5
cp -av lib/lib*.so.5* /usr/lib
cd ..
rm -rf ncurses*/
touch $BLOGDIR/ncurses1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing ATTR.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/attr1.txt ]; then
rm -rf attr*/
bash extract.sh attr
cd attr*/
sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
sed -i -e "/SUBDIRS/s|man[25]||g" man/Makefile
./configure --prefix=/usr                                                \
            --disable-static
make
make install install-dev install-lib
chmod -v 755 /usr/lib/libattr.so
mv -v /usr/lib/libattr.so.* /lib
ln -fsv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
cd ..
rm -rf attr*/
touch $BLOGDIR/attr1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing ACL.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/acl1.txt ]; then
rm -rf acl*/
bash extract.sh acl
cd acl*/
sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
# fixing some broken crap
sed -i "s:| sed.*::g" test/{sbits-restore,cp,misc}.test
sed -i -e "/TABS-1;/a if (x > (TABS-1)) x = (TABS-1);"                   \
    libacl/__acl_to_any_text.c
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --libexecdir=/usr/lib
make
make install install-dev install-lib
chmod -v 755 /usr/lib/libacl.so
mv -v /usr/lib/libacl.so.* /lib
ln -fsv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
cd ..
rm -rf acl*/
touch $BLOGDIR/acl1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing LIBCAP.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/libcap1.txt ]; then
rm -rf libcap*/
bash extract.sh libcap
cd libcap*/
sed -i '/install.*STALIBNAME/d' libcap/Makefile
make
make RAISE_SETFCAP=no lib=lib prefix=/usr install
chmod -v 755 /usr/lib/libcap.so
mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
cd ..
rm -rf libcap*/
touch $BLOGDIR/libcap1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing SED.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/sed1.txt ]; then
rm -rf sed*/
bash extract.sh sed
cd sed*/
sed -i 's/usr/tools/'       build-aux/help2man
sed -i 's/panic-tests.sh//' Makefile.in
./configure --prefix=/usr --bindir=/bin
make
make html
make install
#TODO: replace "4.4" with glob pattern
install -d -m755           /usr/share/doc/sed-4.4
install -m644 doc/sed.html /usr/share/doc/sed-4.4
cd ..
rm -rf sed*/
touch $BLOGDIR/sed1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing SHADOW.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/shadow1.txt ]; then
rm -rf shadow*/
bash extract.sh shadow
cd shadow*/
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
# use SHA-512 instead of crypt
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@'                 \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
# fix bug when interfacing with useradd
echo '--- src/useradd.c   (old)
+++ src/useradd.c   (new)
@@ -2027,6 +2027,8 @@
        is_shadow_grp = sgr_file_present ();
 #endif
+       get_defaults ();
+
        process_flags (argc, argv);
 #ifdef ENABLE_SUBIDS
@@ -2036,8 +2038,6 @@
            (!user_id || (user_id <= uid_max && user_id >= uid_min));
 #endif                         /* ENABLE_SUBIDS */
-       get_defaults ();
-
 #ifdef ACCT_TOOLS_SETUID
 #ifdef USE_PAM
        {' | patch -p0 -l
sed -i 's/1000/999/' etc/useradd
# security issue fix
sed -i -e '47 d' -e '60,65 d' libmisc/myname.c
./configure --sysconfdir=/etc --with-group-name-max-length=32
make
make install
mv -v /usr/bin/passwd /bin
# configuring shadow
# enable shadowed passwords
pwconv
# enable shadowed group passwords
grpconv
# create mailboxes for new users
sed -i 's/yes/no/' /etc/default/useradd
cd ..
# set empty root password for now
passwd -d root
rm -rf shadow*/
touch $BLOGDIR/shadow1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing PSMISC.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/psmisc1.txt ]; then
rm -rf psmisc*/
bash extract.sh psmisc
cd psmisc*/
./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin
cd ..
rm -rf psmisc*/
touch $BLOGDIR/psmisc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing IANA-ETC.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/iana-etc1.txt ]; then
rm -rf iana-etc*/
bash extract.sh iana-etc
cd iana-etc*/
make
make install
cd ..
rm -rf iana-etc*/
touch $BLOGDIR/iana-etc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing BISON.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bison1.txt ]; then
rm -rf bison*/
bash extract.sh bison
cd bison*/
#TODO: replace "3.0.4" with glob pattern
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.4
make
make install
cd ..
rm -rf bison*/
touch $BLOGDIR/bison1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing FLEX.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/flex1.txt ]; then
rm -rf flex*/
bash extract.sh flex
cd flex*/
#TODO: replace "2.6.4" with glob pattern
HELP2MAN=/tools/bin/true                                                 \
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
make
make install
ln -sfv flex /usr/bin/lex
cd ..
rm -rf flex*/
touch $BLOGDIR/flex1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GREP.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/grep1.txt ]; then
rm -rf grep*/
bash extract.sh grep
cd grep*/
./configure --prefix=/usr --bindir=/bin
make
make install
cd ..
rm -rf grep*/
touch $BLOGDIR/grep1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing BASH.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bash1.txt ]; then
rm -rf bash*/
bash extract.sh bash
cd bash*/
#TODO: replace "4.4" with glob pattern; don't assume there is a patch in
#      new version-agnostic script
patch -Np1 -i ../bash-4.4-upstream_fixes-1.patch
./configure --prefix=/usr                                                \
            --docdir=/usr/share/doc/bash-4.4                             \
            --without-bash-malloc                                        \
            --with-installed-readline
make
make install
mv -vf /usr/bin/bash /bin
cd ..
rm -rf bash*/
touch $BLOGDIR/bash1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing LIBTOOL.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/libtool1.txt ]; then
rm -rf libtool*/
bash extract.sh libtool
cd libtool*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf libtool*/
touch $BLOGDIR/libtool1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing GDBM.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gdbm1.txt ]; then
rm -rf gdbm*/
bash extract.sh gdbm
cd gdbm*/
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --enable-libgdbm-compat
make
make install
cd ..
rm -rf gdbm*/
touch $BLOGDIR/gdbm1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GPERF.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gperf1.txt ]; then
rm -rf gperf*/
bash extract.sh gperf
cd gperf*/
#TODO: swap out "3.1" with glob pattern
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make
make install
cd ..
rm -rf gperf*/
touch $BLOGDIR/gperf1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing EXPAT.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/expat1.txt ]; then
rm -rf expat*/
bash extract.sh expat
cd expat*/
# fix a bug with regression tests
sed -i 's|usr/bin/env |bin/|' run.sh.in
./configure --prefix=/usr --disable-static
make
make install
#TODO: replace "2.2.3" with glob pattern
install -v -dm755 /usr/share/doc/expat-2.2.3
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.3
cd ..
rm -rf expat*/
touch $BLOGDIR/expat1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing INETUTILS.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/inetutils1.txt ]; then
rm -rf inetutils*/
bash extract.sh inetutils
cd inetutils*/
./configure --prefix=/usr                                                \
            --localstatedir=/var                                         \
            --disable-logger                                             \
            --disable-whois                                              \
            --disable-rcp                                                \
            --disable-rexec                                              \
            --disable-rlogin                                             \
            --disable-rsh                                                \
            --disable-servers
make
make install
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
cd ..
rm -rf inetutils*/
touch $BLOGDIR/inetutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing PERL.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/perl1.txt ]; then
rm -rf perl*/
bash extract.sh perl
cd perl*/
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des -Dprefix=/usr                                          \
                  -Dvendorprefix=/usr                                    \
                  -Dman1dir=/usr/share/man/man1                          \
                  -Dman3dir=/usr/share/man/man3                          \
                  -Dpager="/usr/bin/less -isR"                           \
                  -Duseshrplib
make
make install
unset BUILD_ZLIB BUILD_BZIP2
cd ..
rm -rf perl*/
touch $BLOGDIR/perl1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                        Installing XML::PARSER.                         #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/xml-parser1.txt ]; then
rm -rf XML-Parser*/
bash extract.sh XML-Parser
cd XML-Parser*/
perl Makefile.PL
make
make install
cd ..
rm -rf XML-Parser*/
touch $BLOGDIR/xml-parser1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing INTLTOOL.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/intltool1.txt ]; then
rm -rf intltool*/
bash extract.sh intltool
cd intltool*/
# fix a warning coused by Perl 5.22 and later
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd ..
rm -rf intltool*/
touch $BLOGDIR/intltool1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                          Installing AUTOCONF.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/autoconf1.txt ]; then
rm -rf autoconf*/
bash extract.sh autoconf
cd autoconf*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf autoconf*/
touch $BLOGDIR/autoconf1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing AUTOMAKE.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/automake1.txt ]; then
rm -rf automake*/
bash extract.sh automake
cd automake*/
#TODO: replace "1.15.1" with glob pattern
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.15.1
make
sed -i "s:./configure:LEXLIB=/usr/lib/libfl.a &:"                        \
       t/lex-{clean,depend}-cxx.sh
make install
cd ..
rm -rf automake*/
touch $BLOGDIR/automake1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                             Installing XZ.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/xz1.txt ]; then
rm -rf xz*/
bash extract.sh xz
cd xz*/
#TODO: replace "5.2.3" with glob pattern
./configure --prefix=/usr                                                \
            --disable-static                                             \
            --docdir=/usr/share/doc/xz-5.2.3
make
make install
mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
cd ..
rm -rf xz*/
touch $BLOGDIR/xz1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                            Installing KMOD.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/kmod1.txt ]; then
rm -rf kmod*/
bash extract.sh kmod
cd kmod*/
./configure --prefix=/usr                                                \
            --bindir=/bin                                                \
            --sysconfdir=/etc                                            \
            --with-rootlibdir=/lib                                       \
            --with-xz                                                    \
            --with-zlib
make
make install
for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod
cd ..
rm -rf kmod*/
touch $BLOGDIR/kmod1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing GETTEXT.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gettext1.txt ]; then
rm -rf gettext*/
bash extract.sh gettext
cd gettext*/
#TODO: replace version number with glob pattern
# suppress things that could cause an infinite loop on accident
sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.19.8.1
make
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd ..
rm -rf gettext*/
touch $BLOGDIR/gettext1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing SYSTEMD.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/systemd1.txt ]; then
rm -rf systemd*/
bash extract.sh systemd
cd systemd*/
# fix a build error when using util-linux
sed -i "s:blkid/::" $(grep -rl "blkid/blkid.h")
# disable 2 tests that always fail
sed -e 's@test/udev-test.pl @@'                                          \
    -e 's@test-copy$(EXEEXT) @@'                                         \
    -i Makefile.in
# remove some inefficiency
cat > config.cache << "EOF"
KILL=/bin/kill
MOUNT_PATH=/bin/mount
UMOUNT_PATH=/bin/umount
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include/blkid"
HAVE_LIBMOUNT=1
MOUNT_LIBS="-lmount"
MOUNT_CFLAGS="-I/tools/include/libmount"
cc_cv_CFLAGS__flto=no
SULOGIN="/sbin/sulogin"
XSLTPROC="/usr/bin/xsltproc"
EOF
#TODO: replace version number with glob pattern
./configure --prefix=/usr                                                \
            --sysconfdir=/etc                                            \
            --localstatedir=/var                                         \
            --config-cache                                               \
            --with-rootprefix=                                           \
            --with-rootlibdir=/lib                                       \
            --enable-split-usr                                           \
            --disable-firstboot                                          \
            --disable-ldconfig                                           \
            --disable-sysusers                                           \
            --without-python                                             \
            --with-default-dnssec=no                                     \
            --docdir=/usr/share/doc/systemd-234
make LIBRARY_PATH=/tools/lib
make LD_LIBRARY_PATH=/tools/lib install
# remove unnecessary directory
rm -rfv /usr/lib/rpm
# creaty sysvinit compatibility symlinks
for tool in runlevel reboot shutdown poweroff halt telinit; do
     ln -sfv ../bin/systemctl /sbin/${tool}
done
ln -sfv ../lib/systemd/systemd /sbin/init
# setup machine-id file needed by journald
systemd-machine-id-setup
cd ..
rm -rf systemd*/
touch $BLOGDIR/systemd1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing PROCPS-NG.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/procps-ng1.txt ]; then
rm -rf procps-ng*/
bash extract.sh procps-ng
cd procps-ng*/
#TODO: replace version number with glob pattern
./configure --prefix=/usr                                                \
            --exec-prefix=                                               \
            --libdir=/usr/lib                                            \
            --docdir=/usr/share/doc/procps-ng-3.3.12                     \
            --disable-static                                             \
            --disable-kill                                               \
            --with-systemd
make
sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
make install
mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
cd ..
rm -rf procps-ng*/
touch $BLOGDIR/procps-ng1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                         Installing E2FSPROGS.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/etwofsprogs1.txt ]; then
rm -rf e2fsprogs*/
bash extract.sh e2fsprogs
cd e2fsprogs*/
mkdir build && cd build
LIBS=-L/tools/lib                                                        \
CFLAGS=-I/tools/include                                                  \
PKG_CONFIG_PATH=/tools/lib/pkgconfig                                     \
../configure --prefix=/usr                                               \
             --bindir=/bin                                               \
             --with-root-prefix=""                                       \
             --enable-elf-shlibs                                         \
             --disable-libblkid                                          \
             --disable-libuuid                                           \
             --disable-uuidd                                             \
             --disable-fsck
make
ln -sfv /tools/lib/lib{blk,uu}id.so.1 lib
make install
make install-libs
# make static libs writable so debugging symbols can be later stripped
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
# install info file
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
# create and install additional documentation
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
cd ../..
rm -rf e2fsprogs*/
touch $BLOGDIR/etwofsprogs1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing COREUTILS.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/coreutils1.txt ]; then
rm -rf coreutils*/
bash extract.sh coreutils
cd coreutils*/
#TODO: replace version number with glob pattern
patch -Np1 -i ../coreutils-8.27-i18n-1.patch
# suppress an infinite loop
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
FORCE_UNSAFE_CONFIGURE=1 ./configure                                     \
            --prefix=/usr                                                \
            --enable-no-install-program=kill,uptime
FORCE_UNSAFE_CONFIGURE=1 make
make install
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
mv -v /usr/bin/{head,sleep,nice,test,[} /bin
cd ..
rm -rf coreutils*/
touch $BLOGDIR/coreutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing DIFFUTILS.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/diffutils1.txt ]; then
rm -rf diffutils*/
bash extract.sh diffutils
cd diffutils*/
# allow all locales to be installed
sed -i 's:= @mkdir_p@:= /bin/mkdir -p:' po/Makefile.in.in
./configure --prefix=/usr
make
make install
cd ..
rm -rf diffutils*/
touch $BLOGDIR/diffutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing GAWK.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gawk1.txt ]; then
rm -rf gawk*/
bash extract.sh gawk
cd gawk*/
./configure --prefix=/usr
make
make install
# install the documentation
#TODO: replace version number with glob pattern
mkdir -v /usr/share/doc/gawk-4.1.4
cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.1.4
cd ..
rm -rf gawk*/
touch $BLOGDIR/gawk1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing FINDUTILS.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/findutils1.txt ]; then
rm -rf findutils*/
bash extract.sh findutils
cd findutils*/
# suppress an infinite loop
sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
cd ..
rm -rf findutils*/
touch $BLOGDIR/findutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GROFF.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/groff1.txt ]; then
rm -rf groff*/
bash extract.sh groff
cd groff*/
# change page size to "A4" if you are in Europe
PAGE=letter ./configure --prefix=/usr
make
make install
cd ..
rm -rf groff*/
touch $BLOGDIR/groff1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing GRUB2.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/grubtwo1.txt ]; then
rm -rf grub*/
bash extract.sh grub
cd grub*/
./configure --prefix=/usr                                                \
            --sbindir=/sbin                                              \
            --sysconfdir=/etc                                            \
            --disable-efiemu                                             \
            --disable-werror
make
make install
cd ..
rm -rf grub*/
touch $BLOGDIR/grubtwo1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                            Installing LESS.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/less1.txt ]; then
rm -rf less*/
bash extract.sh less
cd less*/
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf less*/
touch $BLOGDIR/less1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing GZIP.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gzip1.txt ]; then
rm -rf gzip*/
bash extract.sh gzip
cd gzip*/
./configure --prefix=/usr
make
make install
mv -v /usr/bin/gzip /bin
cd ..
rm -rf gzip*/
touch $BLOGDIR/gzip1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                          Installing IPROUTE.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/iproute1.txt ]; then
rm -rf iproute*/
bash extract.sh iproute
cd iproute*/
# don't need arpd
sed -i /ARPD/d Makefile
sed -i 's/arpd.8//' man/man8/Makefile
rm -v doc/arpd.sgml
# disable module requiring iptables
sed -i 's/m_ipt.o//' tc/Makefile
make
#TODO: replace version number with glob pattern
make DOCDIR=/usr/share/doc/iproute2-4.12.0 install
cd ..
rm -rf iproute*/
touch $BLOGDIR/iproute1.txt
fi


#------------------------------------------------------------------------#
#                                                                        #
#                            Installing KBD.                             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/kbd1.txt ]; then
rm -rf kbd*/
bash extract.sh kbd
cd kbd*/
#TODO: replace version number with glob pattern
patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
PKG_CONFIG_PATH=/tools/lib/pkgconfig                                     \
./configure --prefix=/usr                                                \
            --disable-vlock
make
make install
# install documentation
mkdir -v            /usr/share/doc/kbd-2.0.4
cp -R -v docs/doc/* /usr/share/doc/kbd-2.0.4
cd ..
rm -rf kbd*/
touch $BLOGDIR/kbd1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                        Installing LIBPIPELINE.                         #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/libpipeline1.txt ]; then
rm -rf libpipeline*/
bash extract.sh libpipeline
cd libpipeline*/
PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr
make
make install
cd ..
rm -rf libpipeline*/
touch $BLOGDIR/libpipeline1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing MAKE.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/make1.txt ]; then
rm -rf make*/
bash extract.sh make
cd make*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf make*/
touch $BLOGDIR/make1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing PATCH.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/patch1.txt ]; then
rm -rf patch*/
bash extract.sh patch
cd patch*/
./configure --prefix=/usr
make
make install
cd ..
rm -rf patch*/
touch $BLOGDIR/patch1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                            Installing DBUS.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/dbus1.txt ]; then
rm -rf dbus*/
bash extract.sh dbus
cd dbus*/
#TODO: replace version number with glob pattern
./configure --prefix=/usr                                                \
            --sysconfdir=/etc                                            \
            --localstatedir=/var                                         \
            --disable-static                                             \
            --disable-doxygen-docs                                       \
            --disable-xml-docs                                           \
            --docdir=/usr/share/doc/dbus-1.10.22                         \
            --with-console-auth-dir=/run/console
make
make install
mv -v /usr/lib/libdbus-1.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libdbus-1.so) /usr/lib/libdbus-1.so
ln -sfv /etc/machine-id /var/lib/dbus
cd ..
rm -rf dbus*/
touch $BLOGDIR/dbus1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                         Installing UTIL-LINUX.                         #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/util-linux1.txt ]; then
rm -rf util-linux*/
bash extract.sh util-linux
cd util-linux*/
mkdir -pv /var/lib/hwclock
#TODO: replace version number with glob pattern
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime                        \
            --docdir=/usr/share/doc/util-linux-2.30.1                    \
            --disable-chfn-chsh                                          \
            --disable-login                                              \
            --disable-nologin                                            \
            --disable-su                                                 \
            --disable-setpriv                                            \
            --disable-runuser                                            \
            --disable-pylibmount                                         \
            --disable-static                                             \
            --without-python
make
make install
cd ..
rm -rf util-linux*/
touch $BLOGDIR/util-linux1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing MAN-DB.                           #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/man-db1.txt ]; then
rm -rf man-db*/
bash extract.sh man-db
cd man-db*/
#TODO: replace version number with glob pattern
./configure --prefix=/usr                                                \
            --docdir=/usr/share/doc/man-db-2.7.6.1                       \
            --sysconfdir=/etc                                            \
            --disable-setuid                                             \
            --enable-cache-owner=bin                                     \
            --with-browser=/usr/bin/lynx                                 \
            --with-vgrind=/usr/bin/vgrind                                \
            --with-grap=/usr/bin/grap
make
make install
# remove a reference to a nonexistent user
sed -i "s:man man:root root:g" /usr/lib/tmpfiles.d/man-db.conf
cd ..
rm -rf man-db*/
touch $BLOGDIR/man-db1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                             Installing TAR.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/tar1.txt ]; then
rm -rf tar*/
bash extract.sh tar
cd tar*/
FORCE_UNSAFE_CONFIGURE=1                                                 \
./configure --prefix=/usr                                                \
            --bindir=/bin
make
make install
#TODO: replace version number with glob pattern
make -C doc install-html docdir=/usr/share/doc/tar-1.29
cd ..
rm -rf tar*/
touch $BLOGDIR/tar1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                           Installing TEXINFO.                          #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/texinfo1.txt ]; then
rm -rf texinfo*/
bash extract.sh texinfo
cd texinfo*/
./configure --prefix=/usr --disable-static
make
make install
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
rm -v dir
for f in *
  do install-info $f dir 2>/dev/null
done
popd
cd ..
rm -rf texinfo*/
touch $BLOGDIR/texinfo1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                             Installing VIM.                            #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/vim1.txt ]; then
rm -rf vim*/
bash extract.sh vim
cd vim*/
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
make install
# vi is now vim
ln -sfv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sfv vim.1 $(dirname $L)/vi.1
done
# for consistent documentation
#TODO: replace version number with glob pattern
ln -sfv ../vim/vim80/doc /usr/share/doc/vim-8.0.586
# for a more vi-like experience
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc
set nocompatible
set backspace=2
set mouse=r
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
" End /etc/vimrc
EOF
cd ..
rm -rf vim*/
touch $BLOGDIR/vim1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

# we need to keep the BLOGDIR in tact this time to copy over the finished
#   status through the driver script to the logs directory outside of the
#   chroot environment
touch $BLOGDIR/06-buildpartone-finished.txt
