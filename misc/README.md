# misc

This folder contains miscellaneous files, scripts, playbooks, etc. for building and installing various things. Everything here is optional to use.

## playbooks

This folder contains playbooks for installing various packages. Currently, there is only one playbook -- `gcc_installer`. You can use this playbook to install any version of gcc you'd like, especially if your current version of RHEL does not have a version of gcc required by TensorFlow, etc..

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
