# misc

This folder contains miscellaneous files, scripts, playbooks, etc. for building and installing various things. Everything here is optional to use.

## playbooks

This folder contains playbooks for installing various packages. If you wish to use newer versions of TensorFlow with RHEL 7, you will need to install the packages contained here.

In order to install everything properly, run each playbook in the order below:

### gcc\_installer

By default, `gcc` will be built under `/home/build/gcc` and installed to `/usr/local/gcc-9.2.0`. If you are okay with these paths and using version `9.2.0`, then run

```
$ cd playbooks/gcc_installer
$ ansible-playbook -i hosts play.yaml
```

Or if you'd like to use different paths, etc., you can use the `--extra-vars` parameter when running the playbook. For example, if you'd like to install GCC version `8.1.0`, then you would run:

```
$ cd playbooks/gcc_installer
$ ansible-playbook -i hosts play.yaml --extra-vars="{version: '8.1.0'}"
```

You can also change the build path and install prefix via the `install_prefix` and `build_path` extra variables. If the GCC mirror doesn't work, then pass in a different mirror URL via the `gnu_mirror` extra variable. (See `playbooks/gcc_installer/play.yaml` for more info on where to find GNU FTP mirrors.)

### make

To build and install 'make',

```
$ cd playbooks/make_installer
$ ansible-playbook -i hosts play.yaml --extra-vars="{cc: '/path/to/your/newly/installed/gcc'}"
```

This will install `make` to `/usr/local/bin`, unless you specify a different install path via the `install_prefix` extra variable. Also, like with `gcc`, you can choose a different GNU mirror via the `gnu_mirror` extra variable.

### bison

To build and install 'bison',

```
$ cd playbooks/bison_installer
$ ansible-playbook -i hosts play.yaml --extra-vars="{cc: '/path/to/your/newly/installed/gcc', make: '/path/to/your/newly/installed/make'}"
```
This will install `bison` to `/usr/local/bin`, unless you specify a different install path via the `install_prefix` extra variable. You can also use `gnu_mirror` to change the mirror.

### texinfo

To build and install 'texinfo',

```
$ cd playbooks/bison_installer
$ ansible-playbook -i hosts play.yaml --extra-vars="{cc: '/path/to/your/newly/installed/gcc', make: '/path/to/your/newly/installed/make'}"
```

This will install `makeinfo`, etc. to `/usr/local/bin`, unless you specify a different install path via the `install_prefix` extra variable. And yet again, you can use `gnu_mirror` to change the mirror.

### glibc\_installer

To build 'glibc',

```
$ cd playbooks/glibc_installer
$ ansible-playbook -i hosts play.yaml --extra-vars="{cc: '/path/to/your/newly/installed/gcc', make: '/path/to/your/newly/installed/make', bison: '/path/to/your/newly/installed/bison', makeinfo: '/path/to/your/newly/installed/makeinfo'}"
```
