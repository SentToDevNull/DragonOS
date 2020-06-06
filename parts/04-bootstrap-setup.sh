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
#                             Preliminaries...                           #
#                                                                        #
#------------------------------------------------------------------------#

# use ANSI escape codes to colorize output
RED='\033[0;31m'
GREEN='\033[0;32m'
# revert to no color
NC='\033[0m'

# log directory for logs of build progress for pausing and resuming work
mkdir -p $LFS/sources/buildlogs
BLOGDIR=$LFS/sources/buildlogs

cd $LFS/sources

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of BINUTILS.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/binutils1.txt ]; then
rm -rf binutils*/
bash extract.sh binutils
cd binutils*/
mkdir -v build && cd build
../configure --prefix=/tools                                             \
             --with-sysroot=$LFS                                         \
             --with-lib-path=/tools/lib                                  \
             --target=$LFS_TGT                                           \
             --disable-nls                                               \
             --disable-werror

make
# this case ensures the sanity of the toolchain on x86_64 systems
case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
make install
cd .. && rm -rf build
cd ..
rm -rf binutils*/
touch $BLOGDIR/binutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Build the bootstrapping version of GCC.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gcc1.txt ]; then
rm -rf gcc*/
# build GMP, MPFR, and MPC with GCC
bash extract.sh gcc
cd gcc*/
tar -xf ../mpfr*.xz
mv mpfr* mpfr
tar -xf ../gmp*.xz
mv gmp* gmp
tar -xf ../mpc*.gz
mv mpc* mpc
# use only our project's dynamic linker and header files
for file in gcc/config/{linux,i386/linux{,64}}.h; do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g'      \
      $file.orig > $file
  echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
# set lib as default directory for 64-bit libraries
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
# configure and build GCC
mkdir -v build && cd build
../configure                                                             \
    --target=$LFS_TGT                                                    \
    --prefix=/tools                                                      \
    --with-glibc-version=2.11                                            \
    --with-sysroot=$LFS                                                  \
    --with-newlib                                                        \
    --without-headers                                                    \
    --with-local-prefix=/tools                                           \
    --with-native-system-header-dir=/tools/include                       \
    --disable-nls                                                        \
    --disable-shared                                                     \
    --disable-multilib                                                   \
    --disable-decimal-float                                              \
    --disable-threads                                                    \
    --disable-libatomic                                                  \
    --disable-libgomp                                                    \
    --disable-libmpx                                                     \
    --disable-libquadmath                                                \
    --disable-libssp                                                     \
    --disable-libvtv                                                     \
    --disable-libstdcxx                                                  \
    --enable-languages=c,c++
make
make install
cd .. && rm -rf build
cd ..
rm -rf gcc*/
touch $BLOGDIR/gcc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#       Unpack the bootstrapping version of LINUX KERNEL headers.        #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/kernelheaders1.txt ]; then
rm -rf linux*/
bash extract.sh linux
cd linux*/
make mrproper
# time to unpack linux headers to expose kernel API to glibc
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd ..
rm -rf linux*/
touch $BLOGDIR/kernelheaders1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of GLIBC.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/glibc1.txt ]; then
rm -rf glibc*/
bash extract.sh glibc
cd glibc*/
mkdir build && cd build
../configure                                                             \
      --prefix=/tools                                                    \
      --host=$LFS_TGT                                                    \
      --build=$(../scripts/config.guess)                                 \
      --enable-kernel=3.2                                                \
      --with-headers=/tools/include                                      \
      libc_cv_forced_unwind=yes                                          \
      libc_cv_c_cleanup=yes
make
make install
# check to see if compiling and linking with the new toolchain are working
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
# checking if the correct ld library is being used
INTERPRETER=$(readelf -l a.out | grep ': /tools' | sed "s/\(.*\): //g" |
                                                   sed "s/]\(.*\)//g")
if [ $INTERPRETER == "/tools/lib64/ld-linux-x86-64.so.2" ]
  then echo -e "Interpreter Test: ${GREEN}OK${NC}"
  else echo -e "Interpreter Test: ${RED}FAIL${NC}" && exit 1
fi
# clean up test files
rm -v dummy.c a.out
cd .. && rm -rf build/
cd ..
rm -rf glibc*/
touch $BLOGDIR/glibc1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of LIBSTDC++.              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/libstdcpp1.txt ]; then
rm -rf gcc*/
# libstdc++ is located within GCC sources
bash extract.sh gcc
cd gcc*/
mkdir build && cd build
../libstdc++-v3/configure                                                \
    --host=$LFS_TGT                                                      \
    --prefix=/tools                                                      \
    --disable-multilib                                                   \
    --disable-nls                                                        \
    --disable-libstdcxx-threads                                          \
    --disable-libstdcxx-pch                                              \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/7.2.0
make
make install
cd .. && rm -rf build
cd ..
rm -rf gcc*/
touch $BLOGDIR/libstdcpp1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#     Build the bootstrapping version of BINUTILS with the new GCC.      #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/binutils2.txt ]; then
rm -rf binutils*/
bash extract.sh binutils
cd binutils*/
mkdir build && cd build
CC=$LFS_TGT-gcc                                                          \
AR=$LFS_TGT-ar                                                           \
RANLIB=$LFS_TGT-ranlib                                                   \
../configure                                                             \
    --prefix=/tools                                                      \
    --disable-nls                                                        \
    --disable-werror                                                     \
    --with-lib-path=/tools/lib                                           \
    --with-sysroot
make
make install
# preparing the linker for the readjusting phase to come
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd ../..
rm -rf binutils*/
touch $BLOGDIR/binutils2.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#     Build the bootstrapping version of GCC with the new BINUTILS.      #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gcc2.txt ]; then
rm -rf gcc*/
# now we're finally going to compile a full gcc with the new headers
bash extract.sh gcc
cd gcc*/
cat gcc/limitx.h gcc/glimits.h gcc/limity.h >                            \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g'      \
      $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
esac
tar -xf ../mpfr*.xz
mv mpfr* mpfr
tar -xf ../gmp*.xz
mv gmp* gmp
tar -xf ../mpc*.gz
mv mpc* mpc

mkdir build && cd build
CC=$LFS_TGT-gcc                                                          \
CXX=$LFS_TGT-g++                                                         \
AR=$LFS_TGT-ar                                                           \
RANLIB=$LFS_TGT-ranlib                                                   \
../configure                                                             \
    --prefix=/tools                                                      \
    --with-local-prefix=/tools                                           \
    --with-native-system-header-dir=/tools/include                       \
    --enable-languages=c,c++                                             \
    --disable-libstdcxx-pch                                              \
    --disable-multilib                                                   \
    --disable-bootstrap                                                  \
    --disable-libgomp
make
make install
ln -sv gcc /tools/bin/cc
# sanity test the compiler
echo 'int main(){}' > dummy.c
cc dummy.c
# checking if the correct ld library is being used
INTERPRETER=$(readelf -l a.out | grep ': /tools' | sed "s/\(.*\): //g" |
                                                   sed "s/]\(.*\)//g")
# BAD; interpreter should be "/tools/lib64/ld-linux.so.2"
if [ $INTERPRETER == "/tools/lib64/ld-linux-x86-64.so.2" ]
  then echo -e "Interpreter Test: ${GREEN}OK${NC}"
  else echo -e "Interpreter Test: ${RED}FAIL${NC}" && exit 1
fi
# clean up test files
rm -v dummy.c a.out
cd ../..
rm -rf gcc*/
touch $BLOGDIR/gcc2.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of TCL-CORE.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/tcl-core1.txt ]; then
rm -rf tcl*/
bash extract.sh tcl
cd tcl*/
cd unix
./configure --prefix=/tools
make
make install
#TODO: replace "8.6" with glob pattern
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd ../..
rm -rf tcl*/
touch $BLOGDIR/tcl-core1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#              Build the bootstrapping version of EXPECT.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/expect1.txt ]; then
rm -rf expect*/
bash extract.sh expect
cd expect*/
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools                                              \
            --with-tcl=/tools/lib                                        \
            --with-tclinclude=/tools/include
make
make SCRIPTS="" install
cd ..
rm -rf expect*/
touch $BLOGDIR/expect1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#              Build the bootstrapping version of DEJAGNU.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/dejagnu1.txt ]; then
rm -rf dejagnu*/
bash extract.sh dejagnu
cd dejagnu*/
./configure --prefix=/tools
make install
cd ..
rm -rf dejagnu*/
touch $BLOGDIR/dejagnu1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of CHECK.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/check1.txt ]; then
rm -rf check*/
bash extract.sh check
cd check*/
PKG_CONFIG= ./configure --prefix=/tools
make
make install
cd ..
rm -rf check*/
touch $BLOGDIR/check1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#              Build the bootstrapping version of NCURSES.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/ncurses1.txt ]; then
rm -rf ncurses*/
bash extract.sh ncurses
cd ncurses*/
sed -i s/mawk// configure #ensure it's using gawk instead
./configure --prefix=/tools                                              \
            --with-shared                                                \
            --without-debug                                              \
            --without-ada                                                \
            --enable-widec                                               \
            --enable-overwrite
make
make install
cd ..
rm -rf ncurses*/
touch $BLOGDIR/ncurses1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Build the bootstrapping version of BASH.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bash1.txt ]; then
rm -rf bash*/
bash extract.sh bash
cd bash*/
./configure --prefix=/tools --without-bash-malloc # avoiding segfaults
make
make install
ln -sv bash /tools/bin/sh #use bash exclusively
cd ..
rm -rf bash*/
touch $BLOGDIR/bash1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of BISON.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bison1.txt ]; then
rm -rf bison*/
bash extract.sh bison
cd bison*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf bison*/
touch $BLOGDIR/bison1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of BZIP2.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/bziptwo1.txt ]; then
rm -rf bzip2*/
bash extract.sh bzip2
cd bzip2*/
make
make PREFIX=/tools install
cd ..
rm -rf bzip2*/
touch $BLOGDIR/bziptwo1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of COREUTILS.              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/coreutils1.txt ]; then
rm -rf coreutils*/
bash extract.sh coreutils
cd coreutils*/
./configure --prefix=/tools --enable-install-program=hostname
make
make install
cd ..
rm -rf coreutils*/
touch $BLOGDIR/coreutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of DIFFUTILS.              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/diffutils1.txt ]; then
rm -rf diffutils*/
bash extract.sh diffutils
cd diffutils*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf diffutils*/
touch $BLOGDIR/diffutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of FILE.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/file1.txt ]; then
rm -rf file*/
bash extract.sh file
cd file*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf file*/
touch $BLOGDIR/file1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of FINDUTILS.              #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/findutils1.txt ]; then
rm -rf findutils*/
bash extract.sh findutils
cd findutils*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf fileutils*/
touch $BLOGDIR/findutils1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of GAWK.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gawk1.txt ]; then
rm -rf gawk*/
bash extract.sh gawk
cd gawk*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf gawk*/
touch $BLOGDIR/gawk1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#              Build the bootstrapping version of GETTEXT.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gettext1.txt ]; then
rm -rf gettext*/
bash extract.sh gettext
cd gettext*/
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
cd ../..
rm -rf gettext*/
touch $BLOGDIR/gettext1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of GREP.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/grep1.txt ]; then
rm -rf grep*/
bash extract.sh grep
cd grep*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf grep*/
touch $BLOGDIR/grep1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of GZIP.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/gzip1.txt ]; then
rm -rf gzip*/
bash extract.sh gzip
cd gzip*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf gzip*/
touch $BLOGDIR/gzip1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Build the bootstrapping version of M4.                  #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/mfour1.txt ]; then
rm -rf m4*/
bash extract.sh m4
cd m4*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf m4*/
touch $BLOGDIR/mfour1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of MAKE.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/make1.txt ]; then
rm -rf make*/
bash extract.sh make
cd make*/
./configure --prefix=/tools --without-guile
make
make install
cd ..
rm -rf make*/
touch $BLOGDIR/make1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of PATCH.                #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/patch1.txt ]; then
rm -rf patch*/
bash extract.sh patch
cd patch*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf patch*/
touch $BLOGDIR/patch1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#               Build the bootstrapping version of PERL.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/perl1.txt ]; then
rm -rf perl*/
bash extract.sh perl
cd perl*/
sed -e '9751 a#ifndef PERL_IN_XSUB_RE'                                   \
    -e '9808 a#endif'                                                    \
    -i regexec.c
sh Configure -des -Dprefix=/tools -Dlibs=-lm
make
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
#TODO: use glob pattern instead of "5.26.0"
mkdir -pv /tools/lib/perl5/5.26.0
cp -Rv lib/* /tools/lib/perl5/5.26.0
cd ..
rm -rf perl*/
touch $BLOGDIR/perl1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Build the bootstrapping version of SED.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/sed1.txt ]; then
rm -rf sed*/
bash extract.sh sed
cd sed*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf sed*/
touch $BLOGDIR/sed1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                Build the bootstrapping version of TAR.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/tar1.txt ]; then
rm -rf tar*/
bash extract.sh tar
cd tar*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf tar*/
touch $BLOGDIR/tar1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#              Build the bootstrapping version of TEXINFO.               #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/texinfo1.txt ]; then
rm -rf texinfo*/
bash extract.sh texinfo
cd texinfo*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf texinfo*/
touch $BLOGDIR/texinfo1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#             Build the bootstrapping version of UTIL-LINUX.             #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/util-linux1.txt ]; then
rm -rf util-linux*/
bash extract.sh util-linux
cd util-linux*/
./configure --prefix=/tools                                              \
            --without-python                                             \
            --disable-makeinstall-chown                                  \
            --without-systemdsystemunitdir                               \
            --without-ncurses                                            \
            PKG_CONFIG=""
make
make install
cd ..
rm -rf util-linux*/
touch $BLOGDIR/util-linux1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                 Build the bootstrapping version of XZ.                 #
#                                                                        #
#------------------------------------------------------------------------#

if [ ! -f $BLOGDIR/xz1.txt ]; then
rm -rf xz*/
bash extract.sh xz
cd xz*/
./configure --prefix=/tools
make
make install
cd ..
rm -rf xz*/
touch $BLOGDIR/xz1.txt
fi

#------------------------------------------------------------------------#
#                                                                        #
#                    Removing unnecessary components.                    #
#                                                                        #
#------------------------------------------------------------------------#

# this will output stderr, but it doesn't really matter
set +e
# strip unneeded debugging symbols on the boostrapping system
strip --strip-debug /tools/lib/* 2>/dev/null
strip --strip-unneeded /tools/{,s}bin/* 2>/dev/null
# resetting the error catcher
set -e

# remove all documentation from the bootstrapping system to conserve space
rm -rf /tools/{,share}/{info,man,doc}

# remove the build log directory we created to keep track of progress
rm -rf $BLOGDIR

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch $WORDIR/logs/04-bootstrap-setup-finished.txt
