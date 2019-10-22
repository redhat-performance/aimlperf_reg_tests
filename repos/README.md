# Repos

You're probably viewing this README because you want to build a container image with custom RHEL, CUDA, etc. repositories in it. For example, maybe you want to build TensorFlow on the GPU with CUDA toolkit.

To build a custom container image, note that only some of the Dockerfiles that live under`../FFTW/Dockerfiles`, `../OpenBLAS/Dockerfiles`, and `../TensorFlow/Dockerfiles` consume specific `.repo` files during their build. Those `.repo` files, however, do not exist in this repository because they contain private baseurls, so instead, you will need to create your *own* files using the descriptions below, under the assumption you have the right to use the repositories you define in your `.repo` files.

Note that these `.repo` files are *not* the same as `ubi7`, `ubi8`, or their variants. See the RHEL 7 and RHEL 8 sections below for the proper repository names and info.

## RHEL 7 Repos

1. `rhel7-Latest.repo`

The baseurl of this repository file points to the standard RHEL 7 repo. It can point to any version/release of RHEL 7. For example, RHEL 7.3 or RHEL 7.7, etc. etc..

```
[rhel7-Latest]
name=RHEL7-Latest
baseurl=</url/path/to/rhel7-latest/tree>
enabled=1
gpgcheck=0
```

2. `rhel7-Server-Optional.repo`

The baseurl of this repository file points to the Optional repo. As with `rhel7-Latest.repo`, this file can point to any version/release of RHEL 7. Just make sure it aligns with the same version of RHEL that you used for `rhel7-Latest.repo`.

```
[rhel7-Server-Optional]
name=RHEL7-Server-Optional
baseurl=</url/path/to/rhel7-Server-Optional/tree>
enabled=1
gpgcheck=0
```

3. `rhel7-cuda.repo`

The baseurl of this repository file points to the CUDA repo. You will need an NVIDIA developer account to find and access this file. Once you have registered with NVIDIA and signed in, you can find the `cuda-rhel7.repo` file from one of the following two sources:

a. https://developer.nvidia.com/cuda-toolkit-archive
b. https://gitlab.com/nvidia/container-images/cuda/blob/master/dist/ubi7/10.0/base/cuda.repo

Make sure to rename it to `rhel7-cuda.repo` after downloading.

```
[cuda]
name=cuda
baseurl=</url/path/to/nvidia/repo>
enabled=1
gpgcheck=1
gpgkey=</url/path/to/gpg/key>
```

## RHEL 8 Repos

1. `rhel8-Latest.repo`

The baseurl of this repository file points to the standard RHEL 8 repo. It can point to any version/release of RHEL 8. For example, RHEL 8.0 or RHEL 8.1, etc. etc..

```
[rhel8-Latest]
name=RHEL8-Latest
baseurl=</url/path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```

2. `rhel8-Appstream-Latest.repo`

The baseurl of this repository file points to the AppStream repo. As with `rhel8-Latest.repo`, this file can point to any version/release of RHEL 8. Just make sure it aligns with the same version of RHEL that you used for `rhel8-Latest.repo`.

```
[rhel8-Appstream-Latest]
name=RHEL8-Appstream-Latest
baseurl=</url/path/to/rhel8-appstream/tree>
baseurl=</url/path/to/rhel8-latest/tree>
enabled=1
gpgcheck=0
```

3. `rhel8-cuda.repo`

The baseurl of this repository file points to the CUDA repo. You will need an NVIDIA developer account to find and access this file. Once you have registered with NVIDIA and signed in, you can find the `cuda-rhel7.repo` file from one of the following two sources:

a. https://developer.nvidia.com/cuda-toolkit-archive
b. https://gitlab.com/nvidia/container-images/cuda/blob/master/dist/ubi8/10.0/base/cuda.repo

Make sure to rename it to `rhel8-cuda.repo` after downloading.

```
[cuda]
name=cuda
baseurl=</url/path/to/nvidia/repo>
enabled=1
gpgcheck=1
gpgkey=</url/path/to/gpg/key>
```
