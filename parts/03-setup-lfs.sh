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
