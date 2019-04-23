# Repos

In this folder, create your own `.repo` files usable by the Dockerfiles contained in the FFTW and OpenBLAS subfolders under the root of this repo.

Format:

1. `rhel7-Latest.repo`

```
[rhel7-Latest]
name=RHEL7-Latest
baseurl=<path/to/rhel7-latest/tree>
enabled=1
gpgcheck=0
```

2. `rhel8-Latest.repo`

```
[rhel8-Latest]
name=RHEL8-Latest
baseurl=<path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```

3. `rhel8-Appstream-Latest.repo`

```
[rhel8-additional-latest-nightly-appstream]
name=rhel8-additional-latest-nightly-appstream
baseurl=<path/to/rhel8-appstream/nightly/tree>
baseurl=<path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```
