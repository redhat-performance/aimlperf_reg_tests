# Distributed Cloud Files

This folder contains scripts for running TensorFlow across multiple nodes (i.e., it allows TensorFlow to run distributed). It makes use of the `TFJob` custom resource (CR).

## Prerequisites

Before beginning any of the scripts in this folder, make sure you have a running OpenShift or Kubernetes cluster. Once you have a running cluster, you will need to install Kubeflow. Follow the instructions in the next section to install it.

## Kubeflow Installation

For installing Kubeflow in Kubernetes, follow the [instructions here](https://www.kubeflow.org/docs/started/getting-started/).

For installing Kubeflow in OpenShift, either follow the Kubernetes instructions above or follow [Open Data Hub's documentation](https://gitlab.com/opendatahub/opendatahub-operator/-/blob/master/docs/manual-installation.adoc).

## Configure the TFJob and Makefile

Use the `configure` script in this folder to configure the `TFJob` YAML file (for defining the TFJob) and the Makefile (for building a TensorFlow Kubeflow image and executing the TFJob). If you need help with how to use the `configure` script, run:

```bash
$ configure --help
```

For more information on the parameters (e.g., `--parameter-servers` and `--workers`), visit [the Kubeflow documentation](https://www.kubeflow.org/docs/components/training/tftraining/).

## Build the TensorFlow Kubeflow Image

To build the TensorFlow Kubeflow image without pushing it, run:

```bash
$ make build_image
```

Or if you want to build and push the image to a remote repository, run:

```bash
$ podman login <your-repo>
$ make build
```

Once the image has been pushed to your local or remote repository, you will be ready to run the `TFJob`.

## Running the TFJob

Before you run the TFJob, make sure that if your image repository requires a pull secret that you add the pull secret to OpenShift/Kubernetes.

To run the TFJob,

```bash
$ make
```

## Cleaning Up

To clean the TFJob, run:

```bash
$ make clean_tfjob
```

To clean everything,

```bash
$ make clean
```
