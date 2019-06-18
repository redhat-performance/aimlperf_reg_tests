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

To run the regression tests on OpenShift in AWS, view the **OpenBLAS/OpenShift** folder (for OpenBLAS) or **FFTW/OpenShift** (for FFTW). Everything is automated, and there is even a script for creating a new node (MachineSet) in OpenShift in the event you want a specific instance type (e.g., m4.4xlarge, c5.large, etc.).
