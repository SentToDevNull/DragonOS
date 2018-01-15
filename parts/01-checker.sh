#!/bin/bash

#------------------------------------------------------------------------#
#                                                                        #
#        Terminate if any component exits with a non-zero status.        #
#                                                                        #
#------------------------------------------------------------------------#

set -e

#------------------------------------------------------------------------#
#                                                                        #
#      Setting the minimum required versions to build the system.        #
#                                                                        #
#------------------------------------------------------------------------#

BASH_MIN=3.2
BINUTILS_MIN=2.17
BISON_MIN=2.3
BZIPTWO_MIN=1.0.4
COREUTILS_MIN=6.9
DIFFUTILS_MIN=2.8.1
FINDUTILS_MIN=4.2.31
GAWK_MIN=4.0.1
GCC_MIN=4.7
GPLUSPLUS_MIN=4.7
GLIBC_MIN=2.11
GREP_MIN=2.5.1a
GZIP_MIN=1.3.12
LINUX_MIN=3.2
MFOUR_MIN=1.4.10
MAKE_MIN=3.81
PATCH_MIN=2.5.4
PERL_MIN=5.8.8
SED_MIN=4.1.5
TAR_MIN=1.22
TEXINFO_MIN=4.7
XZ_MIN=5.0.0

#------------------------------------------------------------------------#
#                                                                        #
#           Ensuring that no outdated tools are being used...            #
#                                                                        #
#------------------------------------------------------------------------#

# makes $1 point to $2
set_symlink() {
  ln -sf $2 $1
}

set_symlink /bin/sh bash
set_symlink /usr/bin/yacc bison
set_symlink /usr/bin/awk gawk

#------------------------------------------------------------------------#
#                                                                        #
#     Ensuring that the symlinks created above were properly set...      #
#                                                                        #
#------------------------------------------------------------------------#

# check symlink and return error if $1 doesn't point to $2
check_symlink() {
  echo $(readlink -f $1) | grep -iq $2 ||
    (echo "ERROR: $1 does not point to $2." && exit 1)
}

check_symlink /bin/sh bash
check_symlink /usr/bin/yacc bison
check_symlink /usr/bin/awk gawk

#------------------------------------------------------------------------#
#                                                                        #
#                 Removing troublesome libtool files...                  #
#                                                                        #
#------------------------------------------------------------------------#

for lib in lib{gmp,mpfr,mpc}.la; do
  rm -f $(find /usr/lib* -name $lib)
done
unset lib

#------------------------------------------------------------------------#
#                                                                        #
#       Override localization to C for easily-parsable output...         #
#                                                                        #
#------------------------------------------------------------------------#

export LC_ALL=C

#------------------------------------------------------------------------#
#                                                                        #
#               Defining the version checking commands...                #
#                                                                        #
#------------------------------------------------------------------------#

newer_checker() {
  [ "$1" = "$2" ] && return 1 || [  "$2" = "`echo -e "$1\n$2" |
                                             sort -V | head -n1`" ]
}

older_checker() {
  [ "$1" = "$2" ] && return 1 || newer_checker $2 $1
}

check_version() {
  # Determine whether version is too old for build.
  older_checker $1 $2 && echo "0"
  # Determine whether version is just sufficient for build.
  [[ "$1" == $2 ]] && echo "1"
  # Determine whether version is more than sufficient for build.
  newer_checker $1 $2 && echo "1"
}

#------------------------------------------------------------------------#
#                                                                        #
#            Function to output status of system packages...             #
#                                                                        #
#------------------------------------------------------------------------#

# use ANSI escape codes to colorize output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
SUCCESS="${GREEN}OK${NC}"
FAILURE="${RED}FAIL${NC}"

# check if installed package of version $1 is higher than the needed $2
#   and exit with error if a package is outdated
package_condition() {
if [ $(check_version $1 $2) == 1 ]
  then echo -e "$3: $SUCCESS"
  else (echo -e "$3: $FAILURE; required: >= $2." && exit 1)
fi
}

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of BASH...                 #
#                                                                        #
#------------------------------------------------------------------------#

BASH_SYS=$(bash --version | head -n1 | sed "s/\(.*\)version //g" |
                            sed "s/-\(.*\)//g" | sed "s/(\(.*\)//g")
package_condition $BASH_SYS $BASH_MIN BASH

#------------------------------------------------------------------------#
#                                                                        #
#               Check the installed version of BINUTILS...               #
#                                                                        #
#------------------------------------------------------------------------#

BINUTILS_SYS=$(ld --version | head -n1 | sed "s/\(.*\)version //g" |
                              sed "s/-\(.*\)//g" | sed "s/\(.*\)) //g")
package_condition $BINUTILS_SYS $BINUTILS_MIN BINUTILS

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of BISON...                #
#                                                                        #
#------------------------------------------------------------------------#

BISON_SYS=$(bison --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $BISON_SYS $BISON_MIN BISON

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of BZIP2...                #
#                                                                        #
#------------------------------------------------------------------------#

BZIPTWO_SYS=$(bzip2 --version 2>&1 < /dev/null | head -n1 |
              sed "s/\(.*\)Version //g" | sed "s/,\(.*\)//g")
package_condition $BZIPTWO_SYS $BZIPTWO_MIN BZIP2

#------------------------------------------------------------------------#
#                                                                        #
#               Check the installed version of COREUTILS...              #
#                                                                        #
#------------------------------------------------------------------------#

COREUTILS_SYS=$(chown --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $COREUTILS_SYS $COREUTILS_MIN COREUTILS

#------------------------------------------------------------------------#
#                                                                        #
#               Check the installed version of DIFFUTILS...              #
#                                                                        #
#------------------------------------------------------------------------#

DIFFUTILS_SYS=$(diff --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $DIFFUTILS_SYS $DIFFUTILS_MIN DIFFUTILS

#------------------------------------------------------------------------#
#                                                                        #
#               Check the installed version of FINDUTILS...              #
#                                                                        #
#------------------------------------------------------------------------#

FINDUTILS_SYS=$(find --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $FINDUTILS_SYS $FINDUTILS_MIN FINDUTILS

#------------------------------------------------------------------------#
#                                                                        #
#                  Check the installed version of GAWK...                #
#                                                                        #
#------------------------------------------------------------------------#

GAWK_SYS=$(gawk --version | head -n1 | sed "s/GNU Awk //g" |
                                       sed "s/,\(.*\)//g")
package_condition $GAWK_SYS $GAWK_MIN GAWK

#------------------------------------------------------------------------#
#                                                                        #
#                  Check the installed version of GCC...                 #
#                                                                        #
#------------------------------------------------------------------------#

GCC_SYS=$(gcc --version | head -n1 | sed "s/\(.*\) //g") 
package_condition "$GCC_SYS" "$GCC_MIN" "GCC"

#------------------------------------------------------------------------#
#                                                                        #
#                  Check the installed version of G++...                 #
#                                                                        #
#------------------------------------------------------------------------#

GPLUSPLUS_SYS=$(g++ --version | head -n1 | sed "s/\(.*\)GCC) //g" |
                                           sed "s/ \(.*\)//g")
package_condition $GPLUSPLUS_SYS $GPLUSPLUS_MIN G++

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of GLIBC...                #
#                                                                        #
#------------------------------------------------------------------------#

GLIBC_SYS=$(ldd --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $GLIBC_SYS $GLIBC_MIN GLIBC

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of GREP...                 #
#                                                                        #
#------------------------------------------------------------------------#

GREP_SYS=$(grep --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $GREP_SYS $GREP_MIN GREP

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of GZIP...                 #
#                                                                        #
#------------------------------------------------------------------------#

GZIP_SYS=$(gzip --version | head -n1 | sed "s/\(.*\) //g")
package_condition $GZIP_SYS $GZIP_MIN GZIP

#------------------------------------------------------------------------#
#                                                                        #
#                Check the installed version of LINUX...                 #
#                                                                        #
#------------------------------------------------------------------------#

LINUX_SYS=$(cat /proc/version | sed "s/\(.*\)Linux version //g" |
                                sed "s/-\(.*\)//g" | sed "s/ \(.*\)//g")
package_condition $LINUX_SYS $LINUX_MIN LINUX

#------------------------------------------------------------------------#
#                                                                        #
#                  Check the installed version of M4...                  #
#                                                                        #
#------------------------------------------------------------------------#

MFOUR_SYS=$(m4 --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $MFOUR_SYS $MFOUR_MIN M4

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of MAKE...                 #
#                                                                        #
#------------------------------------------------------------------------#

MAKE_SYS=$(make --version | head -n1 | sed "s/\(.*\)GNU Make //g")
package_condition $MAKE_SYS $MAKE_MIN MAKE

#------------------------------------------------------------------------#
#                                                                        #
#                Check the installed version of PATCH...                 #
#                                                                        #
#------------------------------------------------------------------------#

PATCH_SYS=$(patch --version | head -n1 | sed "s/\(.*\)GNU patch //g")
package_condition $PATCH_SYS $PATCH_MIN PATCH

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of PERL...                 #
#                                                                        #
#------------------------------------------------------------------------#

PERL_SYS=$(echo Perl `perl -V:version` | sed "s/\(.*\)='//g" |
                                         sed "s/'\(.*\)//g")
package_condition $PERL_SYS $PERL_MIN PERL

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of SED...                  #
#                                                                        #
#------------------------------------------------------------------------#

SED_SYS=$(sed --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $SED_SYS $SED_MIN SED

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of SED...                  #
#                                                                        #
#------------------------------------------------------------------------#

SED_SYS=$(sed --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $SED_SYS $SED_MIN SED

#------------------------------------------------------------------------#
#                                                                        #
#                 Check the installed version of TAR...                  #
#                                                                        #
#------------------------------------------------------------------------#

TAR_SYS=$(tar --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $TAR_SYS $TAR_MIN TAR

#------------------------------------------------------------------------#
#                                                                        #
#               Check the installed version of MAKEINFO...               #
#                                                                        #
#------------------------------------------------------------------------#

TEXINFO_SYS=$(makeinfo --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $TEXINFO_SYS $TEXINFO_MIN TEXINFO

#------------------------------------------------------------------------#
#                                                                        #
#                  Check the installed version of XZ...                  #
#                                                                        #
#------------------------------------------------------------------------#

XZ_SYS=$(xz --version | head -n1 | sed "s/\(.*\)) //g")
package_condition $XZ_SYS $XZ_MIN XZ

#------------------------------------------------------------------------#
#                                                                        #
#                      Testing whether G++ works...                      #
#                                                                        #
#------------------------------------------------------------------------#

echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
if [ -x dummy ]
  then echo -e "g++ test: $SUCCESS";
  else (echo -e "g++ test: $FAILURE" && exit 1)
fi
rm -f dummy.c dummy

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build should happen. #
#                                                                        #
#------------------------------------------------------------------------#
#exit 1
touch logs/01-checker-finished.txt
