# GPU Packages

This folder contains packages for NCCL and cuDNN. You must download the packages yourself -- using your NVIDIA developer's account -- and place them in this folder.

NCCL can be found here: https://developer.nvidia.com/nccl
cuDNN can be found here: https://developer.nvidia.com/cudnn

For both NCCL and cuDNN, download the OS agnostic installers for Linux (which would be the .tgz file for cuDNN and the .txz file for nccl).

Because these packages are consumed by select Dockerfiles in this repository, you *must* rename your packages as follows:

1. nccl.txz
2. cudnn.tgz
