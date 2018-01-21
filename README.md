# DragonOS

This script builds the target system in its working directory. Before
running it, make sure that any user can access the build directory. It is
recommended that you `chmod 777 /opt/` clone this repository into /opt/,
and build from there.

## TODO
Check whether "development" package is installed rather than just the normal package for host system dependencies where needed.

Add Xorg and i3 and develop separate targets for embedded and desktop system compilation.

Switch to MUSL LibC.
