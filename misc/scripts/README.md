# scripts

This folder contains various scripts. Currently, the only script that exists is `patch_python_new_glibc.sh`.

This script is used to patch a Python executable (e.g., `/usr/bin/python` or `/usr/bin/python3`, etc. etc.) such that it uses a glibc that is different from the stock RHEL one, with the intent of running the `../playbooks/glibc_updater` playbook to update the glibc installation.

Do NOT run this script unless you are okay with patching Python! It is **strongly recommended** that you run this in a container, rather than on bare metal.

To run the script,

```
$ patch_python_new_glibc.sh /path/to/newglibc /path/to/python/executable/to/patch
```

e.g., If you built a new glibc via `../playbooks/glibc_installer` and used the prefix `/usr/local`:

```
$ patch_python_new_glibc.sh /usr/local /usr/bin/python3
```
