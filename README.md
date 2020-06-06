# DragonOS

## About

This is an operating system I created for use in embedded projects.
Designing and compiling any working Linux system completely from scratch
is a difficult process, and automating it entirely such that there is no
error is even more difficult. (It involves understanding how every
version of every component interacts with every other component.) As such,
though this is stable, I will likely not have the time to update this to
use newer versions of the kernel and userland programs.

The kernel is well-enough maintained though that you can drop a newer
version in the build system without suffering any errors.

## Why not just use another operating system?

The key benefit of this operating system is its simplicity. Modern
operating systems have so many components managed by so many different
people that true stability is an impossible goalpost. Those Linux
distributions that manage to achieve some degree of stability (only
Debian and Red Hat) are bloated with redundancies in packages and
settings that nobody understands well enough to clean. A typical
installation can be around 20 GB without a desktop environment and will
have hundreds of services that run in the background wasting memory and
threads on things the user has no use for (and that just 'exist' for
legacy purposes).

Other projects such as Ubuntu and CentOS rip off and rebrand Debian and
Red Hat, respectively, with a few slight adjustments. (And they're every
bit as bloated, without the benefits of stable updates from upstream
sources.)

Companies that develop embedded Linux distributions invariably rip off
other bloated operating systems as well. For example, Xilinx's Petalinux
is just a rebrand of the Yocto project with a heavily-modified kernel
that the developers can't keep up to date. (This is distressing when
you're working on embedded kernel module drivers.)


## What's unique about this project?

This project, is based _entirely_ on upstream sources. It is not based on
any existing operating system and provides all the utilities needed to
develop standard-compliant drivers for embedded systems.

It has all the embedded development tools you'll want to use to develop
drivers, and is _many orders of magnitude_ smaller than other embedded
operating systems.

Package management exists in the build system to blacklist packages from
being installed, and no part of the build system or any other branding is
present in the compiled operating system image.

This OS has a minimal footprint in terms of both resource usage and attack
surface.

This OS is easily virtualizable (using tools like `qemu`) to allow for
rapid testing of your programs.

## How do I build it?

You must be running a modern Linux system to take advantage of the
virtual filesystem utilities that connect the building OS to your
hardware. This is done so that your host system can build the bootstrap
system that will in turn build the operating system (providing separation
between the libraries on your system that would otherwise be linked into
the building system).

I've managed to truly automate it all. Run the script at the root of
this project, which will tell you whether you're missing any dependencies
on your host system that will be needed to build the bootstrapping system.

If you encounter any errors running on your hardware, edit
`parts/kernelconfig.txt` to add in support for your hardware. I added
support in that config for all the hardware in the Thinkpad T560 lineup.

This script builds the target system in its working directory. Before
running it, make sure that any user can access the build directory. It is
recommended that you `chmod 777 /opt/`, clone this repository into /opt/,
and build from there.

## NOTE

Given how tedious this project is to maintain (having to account for
changing config options and dependencies introduced by newer versions of
software), it's advisable to use Gentoo, a meta-distribution, which
abstracts individual config flags across your system into simple USE
statements. See git.lukasyoder.com/sources/gentoo-installer for the
new automated installer I made.

Though Gentoo is more bloated, it is easier to maintain and can actually
be used as a desktop system.
