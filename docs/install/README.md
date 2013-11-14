# <i class="icon-beaker"></i> 3X Installation Instructions

## OS X (Mac) and GNU/Linux

### Download
Binary releases of 3X for common environments can be downloaded from the following page:

* <b><big>[3X Releases][]</big></b>

You must download the correct file for your operating system and processor architecture: `Darwin` is for OS X and `Linux` is for Linux.
After you download the appropriate file, mark it as executable as shown in the following list of commands:

```bash
release=v1.0
system=`uname -s`-`uname -m`
package=3x-$release-$system.sh
# download
curl -RLO https://github.com/netj/3x/releases/download/$release/$package
# make it an executable
chmod +x $package
```

### Install

You should move the executable package to a directory that is on your `$PATH`, and rename it to `3x` to use 3X without typing the long path name every time.
For example, if you already have `~/bin/` on your `$PATH`, simply place the package under it by running commands similar to the following:

```bash
mkdir -p ~/bin
mv $package ~/bin/3x
```

If you don't have `~/bin` on your `$PATH` yet, add the following line to your
`.bash_profile` or `.bashrc`.

```bash
PATH=~/bin:"$PATH"
```

3X documents and instructions contain example commands that may not work correctly on other shells than [bash][].
Unless you are familiar enough with your own shell, please enter a new bash session by typing `bash` first.



## Building from Source

You can build 3X from its source code on other Unix operating systems, or when you are having trouble running the prebuilt packages on your system.

### Get Source and Build

As long as you have a not-too-old version of [Git][] and other [essential compiler and build tools][build-essential] installed on your system, commands similar to the following three lines will produce an executable file, named `3x-VERSION-OS-MACHINE.sh`.
Here, `VERSION` is the version of 3X you are building, and `OS` and `MACHINE` are your operating system and processor architecture that the produced 3X executable can run on.
For example, to download the source code for version `v1.0` and build a 3X executable package, run:

```bash
git clone https://github.com/netj/3x.git --branch v1.0
cd 3x
make
```

### Install from Source

If you want to install the built package from the source tree to `~/bin/`, run this command:

```bash
make install PREFIX=~
```

`PREFIX` can be changed to other locations such as `/usr/local` to install 3X to `/usr/local/bin/`, which may require administrative permissions.
In that case, install the built executable using the `sudo` command:

```bash
sudo install 3x-LATEST-*.sh /usr/local/bin/3x
```



## Windows

Unfortunately, 3X can only run on operating systems that support [POSIX][], and therefore is not available for Windows operating system.
There is no plan to support Windows in the near-term future.
Although not recommended, you might be able to run 3X with [Cygwin][] or other POSIX emulation layers if you have completely no access to a proper POSIX machine.



[3X Releases]: https://github.com/netj/3x/releases

[Bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)

[Git]: http://git-scm.com
[build-essential]: http://superuser.com/a/352002/45702
[POSIX]: https://en.wikipedia.org/wiki/POSIX
[cygwin]: http://cygwin.com

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
