# <i class="icon-beaker"></i> 3X Installation

## OS X (Mac) and GNU/Linux

### Download
Prebuilt binary packages for several common environment are available on the
[3X Releases][] page.  You must download the correct file for your operating
system and processor architecture: `Darwin` is for OS X and `Linux` is for
Linux.  After you download the appropriate package, mark it as executable as
shown in the following generic list of commands:

```bash
release=v1.0
system=`uname -s`-`uname -m`
package=3x-$release-$target.sh
# download
curl -RLO https://github.com/netj/3x/releases/download/$release/$package
# make it an executable
chmod +x $package
```

### Install

You should move the executable package to a directory that is on your `$PATH`,
and rename it to `3x` to use 3X without typing the long path name every time.
For example, if you already have `~/bin/` on your `$PATH`, simply place the
package under it by running commands similar to the following:

```bash
mkdir -p ~/bin
mv 3x-$release-$target.sh ~/bin/3x
```

If you don't have `~/bin` on your `$PATH` yet, add the following line to your
`.bash_profile` or `.bashrc`.

```bash
PATH=~/bin:"$PATH"
```

3X documents and instructions contain example commands that may not work
correctly on other shells than [bash][].  Unless you are familiar enough with your
own shell, please begin a new bash session by running `bash`.



## Building from Source

You can build 3X from source code on other Unix operating systems, or when you
are having trouble running the prebuilt packages on your system.

### Get Source and Build

As long as you have a not-too-old version of [git][] and other [essential
compiler and build tools][build-essential] installed on your system, the
following three commands will produce an executable file, named
`3x-VERSION-OS-MACHINE.sh`.  Here, `VERSION` is the version of 3X you are
building, and `OS` and `MACHINE` are your operating system and processor
architecture that the produced 3X executable can run on.

```bash
git clone https://github.com/netj/3x --branch v1.0
cd 3x
make
```

### Install from Source

If you want to install the package from the source tree to `~/bin/`, simply run
this command:

```bash
make install PREFIX=~
```

`PREFIX` can be changed to other locations such as `/usr/local` to install 3X
to `/usr/local/bin/`, which may require administrative permissions.



## Windows

Unfortunately, 3X can only run on operating systems that support [POSIX][], and
therefore is not available for Windows operating system.  There is no plan to
support Windows in the near-term future.  Although not recommended, you might
be able to run it under [Cygwin][] or other POSIX emulation layers if you don't
have access to a proper POSIX machine.



[3X Releases]: https://github.com/netj/3x/releases

[Bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)

[Git]: http://git-scm.com
[build-essential]: http://superuser.com/a/352002/45702
[POSIX]: https://en.wikipedia.org/wiki/POSIX
[cygwin]: http://cygwin.com

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
