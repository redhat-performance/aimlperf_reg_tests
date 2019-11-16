# Kubernetes

This folder contains scripts for executing TensorFlow builds on Kubernetes. This also works for OpenShift. The difference between the `../OpenShift` folder than this folder is that the `../OpenShift` folder utilizes Source-to-Image (s2i) to execute the TensorFlow builds, and it requires less manual effort.

## Preparing to Create Your Podman/Docker Image (GPU Builds Only)

First, you must create your Podman/Docker image. If you are using GPUs, your first step is to call the `Makefile` in the `setup` directory:

```
$ make -C setup AWS_DIR=~/.aws AWS_PROFILE=<your-profile> CUDNN=s3://your-bucket/path/to/cudnn.tgz NCCL=s3://your-bucket/path/to/nccl.txz TENSORRT=s3://your-bucket/path/to/tensorrt.tar.gz
```

You can leave out TensorRT if you do not wish to use TensorRT.

Note that the `make` command will generate an `aws_env.sh` file that is consumed by the GPU Dockerfile of your choosing. There is no need to edit the `aws_env.sh` file unless you want to.

Once you have done this setup (or if you're using CPUs), you can run `configure`, as described in the next section.

## Configuring the Image Build and Deployment

In order to run the benchmarks in Kubernetes, you must run `configure`, like so:

```bash
$ ./configure [flags]
```

The main flags you should be concerned with:

  - `-v`/`--rhel-version`: The version of RHEL to use. (Currently, only RHEL 7 is supported.)
  - `-b`/`--backend`: The BLAS backend to use (either 'fftw' or 'openblas').
  - `-i`/`--image`: The url of the image you're using (e.g., `quay.io/example-organization/example:exampletag`)
  - `-s`/`--pull-secret`: The pull secret for pulling your image
  - `-d`/`--num-devices`: Number of devices to use. Either CPU or GPU devices.

Flags you might find useful:

  - `-t`/`--instance-type`: For specifying which instance type to run your deployment on

For help on how to use `configure` or to see what other flags are available for using, run:

```bash
$ ./configure --help
```

## Build the Image and Run the Deployment

Run the image build and deployment by running `make`, like so:

```bash
$ make
```

This command will generate a YAML file for creating a Kubernetes deployment, then create a deployment with said YAML file.

If you'd like to run just the image build and push the image to your desired repository,

```bash
$ make build
```

If you'd like to run just the job,

```bash
$ make start_job
```

Also, you can "clean" things by calling the `clean`, `clean_image`, or `clean_job` targets. The `clean_image` target deletes the image from your local docker/podman repo, while the `clean_job` deletes the job from Kubernetes. To clean everything, just call the `clean` target. e.g.,

```bash
$ make clean
```
