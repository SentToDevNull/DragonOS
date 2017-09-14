#!/bin/bash

#------------------------------------------------------------------------#
#                                                                        #
#        Terminate if any component exits with a non-zero status.        #
#                                                                        #
#------------------------------------------------------------------------#

set -e

#------------------------------------------------------------------------#
#                                                                        #
# Creates the user 'lfs', with ownership of the tools and sources dirs.  #
#                                                                        #
#------------------------------------------------------------------------#

# make an unpriveledged user (with empty password) to handle builds and
#   maintain ownership of the tools and sources directories
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
passwd -d lfs
# the 'lfs' user will own these directories
chown lfs $LFS/tools/
chown lfs $LFS/sources/

#------------------------------------------------------------------------#
#                                                                        #
# Writes the file that will be read to determine if build may continue.  #
#                                                                        #
#------------------------------------------------------------------------#

touch logs/03-setup-lfs-finished.txt
