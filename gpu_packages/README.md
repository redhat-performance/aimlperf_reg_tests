# GPU Packages

This folder contains packages for NCCL, cuDNN, and TensorRT. You must download the packages yourself -- using your NVIDIA developer's account -- and place them in this folder.

NCCL can be found here: https://developer.nvidia.com/nccl
cuDNN can be found here: https://developer.nvidia.com/cudnn
TensorRT can be found here: https://developer.nvidia.com/nvidia-tensorrt-download

For both NCCL and cuDNN, download the OS agnostic installers for Linux (which would be the .tgz file for cuDNN and the .txz file for nccl). For TensorRT, use one of the "Tar File Install Packages."

Because these packages are consumed by select Dockerfiles in this repository, you *must* rename your packages so that Podman can find them. For CUDA 10.1 packages, name them as follows:

1. cudnn-cuda-10.1.tgz
2. nccl-cuda-10.1.txz
3. tensorrt-cuda-10.1.tar.gz

For CUDA 10.0 packages, name them as follows:

1. cudnn-cuda-10.0.tgz
2. nccl-cuda-10.0.txz
3. tensorrt-cuda-10.0.tar.gz
