# <i class="icon-beaker"></i> 3X Installation Instructions

<span class="sans-serif">3X</span> supports OS X (Mac), Linux, and other standard Unix systems, but does not work on Windows.
To use the GUI (graphical user interface), you need a modern web browser, such as Safari, Chrome, or Firefox.
<span class="sans-serif">3X</span> is packaged as a single self-contained, executable file, so installation is basically a matter of downloading and copying one file to a special location on your system.


## OS X (Mac) and GNU/Linux

### Download
<span class="sans-serif"><big>**[Latest release of 3X on GitHub][3X Latest Release]**</big></span> contains prebuilt binaries for common environments.
You must download the correct file for your operating system and processor architecture: `Darwin` is for OS X and `Linux` is for Linux.
Downloading the right file for your system could be done automatically using the following series of commands:

```bash
release=v0.9
system=`uname -s`-`uname -m`
package=3x-$release-$system.sh
# download the correct binary from GitHub
curl -RLO https://github.com/netj/3x/releases/download/$release/$package
```


### Install

After you download the appropriate file, mark it as executable as shown in the following command, where `$package` is the path to the file you've just downloaded:

```bash
# make it an executable
chmod +x $package
```

You should move the executable package to a directory that is on your `$PATH`, and rename it to `3x` to use <span class="sans-serif">3X</span> without typing the long path name every time.
For example, if you already have `~/bin/` on your `$PATH`, simply place the package under it by running commands similar to the following:

```bash
mkdir -p ~/bin
mv $package ~/bin/3x
```

If you don't have `~/bin` on your `$PATH` yet, add the following line to your
`.bash_profile` and/or `.bashrc`.

```bash
PATH=~/bin:"$PATH"
```

<span class="sans-serif">3X</span> documents and instructions contain example commands that may not work correctly on other shells than [bash][].
Unless you are familiar enough with your own shell, please enter a new bash session by typing `bash` before using <span class="sans-serif">3X</span>.



## Building from Source

You can build <span class="sans-serif">3X</span> from its source code on other Unix operating systems, or when you are having trouble running the prebuilt packages on your system.

### Get Source and Build

As long as you have a not-too-old version of [Git][] and other [essential compiler and build tools][build-essential] installed on your system, commands similar to the following three lines will produce an executable file, named `3x-VERSION-OS-MACHINE.sh`.
Here, `VERSION` is the version of <span class="sans-serif">3X</span> you are building, and `OS` and `MACHINE` are your operating system and processor architecture that the produced <span class="sans-serif">3X</span> executable can run on.
For example, to download the source code for version `v0.9`, and to build a <span class="sans-serif">3X</span> executable package, run:

```bash
git clone https://github.com/netj/3x.git --branch v0.9
cd 3x
make package
```

### Install from Source

If you want to install the built package from the source tree to `~/bin/`, run this command:

```bash
make install PREFIX=~
```

`PREFIX` can be changed to other locations such as `/usr/local` to install <span class="sans-serif">3X</span> to `/usr/local/bin/`, which may require administrative permissions.
In that case, install the built executable using the `sudo` command:

```bash
sudo install 3x-LATEST-*.sh /usr/local/bin/3x
```



## Windows

Unfortunately, <span class="sans-serif">3X</span> can only run on operating systems that support [POSIX][], and therefore is not available for Windows operating system.
There is no plan to support Windows in the near-term future.
Although not recommended, you might be able to run <span class="sans-serif">3X</span> with [Cygwin][] or other POSIX emulation layers if you have completely no access to a proper POSIX machine.




[3X Latest Release]: https://github.com/netj/3x/releases/latest

[Bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)

[Git]: http://git-scm.com
[build-essential]: http://superuser.com/a/352002/45702
[POSIX]: https://en.wikipedia.org/wiki/POSIX
[cygwin]: http://cygwin.com

<link rel="stylesheet" type="text/css" href="https://netdna.bootstrapcdn.com/font-awesome/3.2.1/css/font-awesome.css">
