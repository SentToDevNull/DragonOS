# DragonOS

This script builds the target system in its working directory. Before
running it, make sure that any user can access the build directory. It is
recommended that you `chmod 777 /opt/`, clone this repository into /opt/,
and build from there.

## NOTE

Given how tedious this project is to maintain (having to account for
changing config options and dependencies introduced by newer versions of
software), it's advisable to use Gentoo, a meta-distribution, which
abstracts individual config flags across your system into simple USE
statements. See git.lukasyoder.com/SentToDevNull/gentoo-installer for the
new automated installer I made.

<!---
## TODO
Check whether "development" package is installed rather than just the
normal package for host system dependencies where needed.

Add Xorg and i3 and develop separate targets for embedded and desktop
system compilation.

Switch to MUSL LibC.
-->
