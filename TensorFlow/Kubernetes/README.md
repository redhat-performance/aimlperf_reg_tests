# Kubernetes

This folder contains scripts for executing TensorFlow builds on Kubernetes. This also works for OpenShift. The difference between the `../OpenShift` folder than this folder is that the `../OpenShift` folder utilizes Source-to-Image (s2i) to execute the TensorFlow builds, and it requires less manual effort.

## Creating Your Podman/Docker Image

First, you must create your Podman/Docker image. Currently, the only Dockerfile that exists for Kubernetes in this repository is `../Dockerfiles/FFTW_backend/Dockerfile.kubernetes_ubi7_cuda10`. It requires **SEVEN (7)** args:

  - `AWS_ACCESS_KEY`: Your AWS access key
  - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key
  - `AWS_REGION`: The AWS region for your account
  - `AWS_PROFILE`: The profile you're using
  - `NCCL`: s3 bucket path to a NCCL tarball (`.txz`)
  - `CUDNN`: s3 bucket path to a cuDNN tarball (`.tgz`)
  - `TENSORRT`: s3 bucket path to a TensorRT tarball (`.tar.gz`)

To build with Podman,

```
$ cd ../../
$ podman build -f TensorFlow/Dockerfiles/FFTW_backend/Dockerfile.kubernetes_ubi7_cuda10 \
               --build-arg AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
               --build-arg AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
               --build-arg AWS_REGION=${AWS_REGION} \
               --build-arg AWS_PROFILE=${AWS_PROFILE} \
               --build-arg NCCL=${NCCL} \
               --build-arg CUDNN=${CUDNN} \
               --build-arg TENSORRT=${TENSORRT} .
```

To build with Docker,

```
$ cd ../../
$ docker build -f TensorFlow/Dockerfiles/FFTW_backend/Dockerfile.kubernetes_ubi7_cuda10 \
               --build-arg AWS_ACCESS_KEY=${AWS_ACCESS_KEY} \
               --build-arg AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
               --build-arg AWS_REGION=${AWS_REGION} \
               --build-arg AWS_PROFILE=${AWS_PROFILE} \
               --build-arg NCCL=${NCCL} \
               --build-arg CUDNN=${CUDNN} \
               --build-arg TENSORRT=${TENSORRT} .
```

## Configuring the Deployment

In order to run the benchmarks in Kubernetes, you must run `configure`, like so:

```bash
$ ./configure [flags]
```

The main flags you should be concerned with:

  - `-i`/`--image`: The url of the image you're using (e.g., `quay.io/example-organization/example:exampletag`)
  - `-s`/`--pull-secret`: The pull secret for pulling your image
  - `-d`/`--num-devices`: Number of devices to use. Either CPU or GPU devices.

Flags you might find useful:

  - `-t`/`--instance-type`: For specifying which instance type to run your deployment on

For help on how to use `configure` or to see what other flags are available for using, run:

```bash
$ ./configure --help
```

## Run the Deployment

Run the deployment by running `make`, like so:

```bash
$ make
```

This command will generate a YAML file for creating a Kubernetes deployment, then create a deployment with said YAML file.
