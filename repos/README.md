# Repos

In this folder, create your own `.repo` files usable by the Dockerfiles contained in the FFTW and OpenBLAS subfolders under the root of this repo.

Format:

1. `rhel7-Latest.repo`

```
[rhel7-Latest]
name=RHEL7-Latest
baseurl=</url/path/to/rhel7-latest/tree>
enabled=1
gpgcheck=0
```

2. `rhel8-Latest.repo`

```
[rhel8-Latest]
name=RHEL8-Latest
baseurl=</url/path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```

3. `rhel8-Appstream-Latest.repo`

```
[rhel8-Appstream-Latest]
name=RHEL8-Appstream-Latest
baseurl=</url/path/to/rhel8-appstream/tree>
baseurl=</url/path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```

4. `cuda.repo`
```
[cuda]
name=cuda
baseurl=</url/path/to/nvidia/repo>
enabled=1
gpgcheck=1
gpgkey=</url/path/to/gpg/key>
```
