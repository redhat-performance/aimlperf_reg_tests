# TensorFlow Playbooks

This folder contains three playbooks for building, installing, and running TensorFlow:

  1. `cuda_optional_installation`
  2. `cudnn_installation`
  3. `nccl_installation`
  4. `package_installation`
  5. `TensorFlow_installation`
  6. `TensorFlow_benchmarks`

The first playbook installs CUDA devel packages for building TensorFlow on the GPU. It requires super user. The second playbook installs cuDNN to /usr/local/cuda (or wherever you've installed CUDA to). The third playbook installs NCCL. The fourth package installs the necessary requirements for building TensorFlow (e.g., required packages, etc.). The fifth package installs TensorFlow itself, but it does not use super user. Instead, it installs the package locally to `${HOME}/.local/lib/python3.6/site-packages`. And finally, the last playbook downloads the benchmarks and runs them.

## CUDA Optional Installation

If you're using CUDA to build TensorFlow on the GPU, make sure you have `/etc/yum.repos.d/cuda.repo` installed. If not, you can find it on NVIDIA's site.

To install the CUDA devel packages,

```
$ cd cuda_optional_installation
$ export RHEL_VERSION=#whatever RHEL version you're using
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: '${RHEL_VERSION}'}"
```

The installation will fail if `/etc/yum.repos.d/cuda.repo` does not exist or if you do not have a CUDA capable GPU.o

## cuDNN Installation

To install cuDNN, 

```
$ cd cudnn_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{ ... }"
```

You can install cuDNN in the following ways:

  1. From an AWS s3 bucket
  2. From an AWS EBS device
  3. From a URL

Set the extra vars based on what you see in `play.yaml`.

## NCCL Installation

To install NCCL,

```
$ cd nccl_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{ ... }"
```

Set the extra vars based on what you see in `play.yaml`.

## Package Installation

To install required packages, first make sure you have write permissions to `/usr/local/lib` and `/usr/lib64`. Once you're ready, you can install the required packages on a RHEL 7 machine via:

```
$ cd package_installation
$ ansible-playbook -i hosts play.yaml
```

Alternatively, for a RHEL 8 machine,

```
$ cd package_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
```

If you would like to install CUDA and NCCL, 

```
$ cd package_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{use_gpu: 'yes', cuda_rpm: <url-to-cuda-rpm>, nccl_rpm: <url-to-nccl-rpm>, cuda_version: <cuda-version>}"
```

Replace `<url-to-cuda-rpm>` with the URL to the CUDA network rpm. Similarly, replace `<url-to-nccl-rpm>` with the URL to the NCCL network rpm. Finally, replace `<cuda-version>` with the version of CUDA you're downloading.

You can also use `rhel_version` as an extra var with the above playbook run command. It is optional, like before.

Note that if you do NOT have an NVIDIA-capable GPU, but you put `use_gpu: 'yes'` in your extra vars, CUDA will NOT be installed because there is error checking to prevent you from corrupting your computer. Thus, it is safe (but not recommended at all) to use `use_gpu: yes` when you don't have an NVIDIA-capable GPU.


## TensorFlow Installation

To install TensorFlow on a RHEL 7 machine,

```
$ cd TensorFlow_installation
$ ansible-playbook -i hosts play.yaml
```

For a RHEL 8 machine,

```
$ cd TensorFlow_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
```

## TensorFlow Benchmarks

To run the Resnet50 TensorFlow benchmarks on a RHEL 7 *or* RHEL 8 machine,

```
$ cd TensorFlow_benchmarks
$ ansible-playbook -i hosts play.yaml
```

Alternatively, you can use a different benchmark by passing in `--extra-vars="{model: <model-name>}"`. Options for `<model-name>` are: `resnet50`, `inception3`, `vgg16`, and `alexnet`.

You can also run the benchmarks on a GPU if you'd prefer the GPU over the CPU. To do so, pass in `--extra-vars="{device: gpu}"

Benchmark results are saved to a file named `[model]-[device]-benchmark-[yyyy]-[mm]-[dd]-[hh]:[mm]:[ss].log` under `${HOME}/tensorflow_benchmarks/tf_cnn_benchmraks`.
