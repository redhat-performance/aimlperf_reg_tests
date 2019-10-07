# aimlperf_reg_tests

## About

This repository contains regression tests for assessing the performance of FFTW, OpenBLAS, etc.. Currently, only FFTW and OpenBLAS have been added.

## Features

The regression tests contained in this repo can be run on bare metal, in a container, or in a container on AWS via OpenShift.

### Bare Metal

To run the OpenBLAS regression tests on bare metal, use the script `run_benchmarks.sh` provided in the OpenBLAS folder. Make sure to compile everything using the compile scripts.

To run the FFTW regression tests on bare metal, use the script `run_benchmarks.sh` provided in the FFTW folder. Make sure to compile everything using the compile scripts.

### Container

To run the OpenBLAS or FFTW regression tests in containers, use the provided Dockerfiles under **OpenBLAS/Dockerfiles** (for OpenBLAS) or **FFTW/Dockerfiles** (for FFTW). See the **README.md** files under the FFTW and OpenBLAS folders to see how to create the containers.

### AWS

To run the regression tests on OpenShift in AWS, view the **OpenBLAS/OpenShift** folder (for OpenBLAS),  **FFTW/OpenShift** (for FFTW), or **TensorFlow/OpenShift** (for TensorFlow). Everything is automated, and there is even a script under **helper\_scripts/OpenShift** for creating a new node (MachineSet) in OpenShift in the event you want a specific instance type (e.g., m4.4xlarge, c5.large, etc.).

To use/enable NFD (Node Feature Discovery), use the script `helper_scripts/OpenShift/nfd_setup.sh`:

```
$ cd helper_scripts/OpenShift
$ sh nfd_setup.sh
```

To use/enable GPUs, use the script `helper_scripts/OpenShift/gpu_setup.sh`. Make sure you run the `nfd_setup.sh` script as well. For GPU setup,

```
$ cd helper_scripts/OpenShift
$ sh gpu_setup.sh
```

To use/enable CPU manager on a specific node for managing CPU resources, use the script `helper_scripts/OpenShift/enable_cpumanager.sh`. To see how it's used,

```
$ cd helper_scripts/OpenShift
$ sh enable_cpumanager.sh -h
```

## Miscellaneous Files

Under the `misc` folder are miscellaneous files for doing various things. Currently, there are a few playbooks for installing `gcc` and `glibc`, along with their dependencies. Running these playbooks is optional, but doing so enables you to install whatever version of `gcc` (and `glibc`) you'd like, which may be useful if your current version of TensorFlow, etc. does not support your existing version of `gcc` (e.g., more recent versions of TensorFlow do not support gcc-4.8.x if trying to build with AVX-512 instructions).

## Secrets

The `secrets` folder contains secrets for various things. For example, you will need a secret to pull images from the redhat.io registry if you wish to use RHEL 8 s2i images.

You can read more information on this by reading the `secrets/README.md` file. Instructions on where/how to obtain these secrets files are listed in the README.

Note that there are no actual "secrets" files contained in this folder, only sample files to show the format of such files.
