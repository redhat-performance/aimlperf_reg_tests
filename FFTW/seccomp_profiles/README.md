# SECCOMP PROFILES

The current profile in this folder is used for running numactl in a Podman container. The profile was written by w1ndy and can be found here: https://gist.github.com/w1ndy/4aee49aa3a608c977a858542ed5f1ee5

Using this profile avoids the need to use `--privileged` with Podman.
