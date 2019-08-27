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

### glibc\_updater

**This playbook is potentially EXTREMELY DESTRUCTIVE**. Do NOT run this playbook unless you are okay with replacing the RHEL glibc installation with the custom one you've built using the `glibc_installer`. Note that you *must* run `scripts/patch_ansible-playbook_new_glibc.sh` before running this playbook.

To ensure that this playbook is not accidentally run, there is a varible `overwrite_rhel_glibc` that is set to `"no"`. Use `sed` or `awk` (or whatever tool you'd like) to change the variable to `"yes"` within a container. Or, manually change it yourself.

## scripts

This folder contains one script so far: `patch_python_new_glibc.sh`. It modifies a user-specified Python executable such that the executable now uses your *new* glibc, rather than the existing RHEL glibc. In order to run it, it takes two arguments: (1) a path that points to your new glibc installation, and (2) a path to the Python executable to 'patch'
