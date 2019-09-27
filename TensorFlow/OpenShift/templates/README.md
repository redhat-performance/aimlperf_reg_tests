# Template Files

The contents of this folder are intended to be used for launching the [official TensorFlow High-Performance CNN benchmarks](https://github.com/tensorflow/benchmarks) as an app in OpenShift on AWS, but you may also use these contents for a non-AWS OpenShift instance.

The benchmarks may be run on the CPU or the GPU, so you can choose whether to use a CPU or GPU instance. Though, if you wish to build TensorFlow locally and run the benchmarks locally, see:

  - `../../playbooks/packages_installation`
  - `../../playbooks/TensorFlow_installation`
  - `../../playbooks/TensorFlow_benchmarks`

With the files contained in the `templates` folder, TensorFlow is built using a custom NumPy compiled with either OpenBLAS or FFTW as a backend, and the official benchmarks are launched as an app.

## Directory Structure

The "standard" folder contains templates necessary for launching a basic TensorFlow image and build job, while the "nfd" folder contains necessary templates for launching a TensorFlow image and build job using [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery). To install Node Feature Discovery (NFD) on your OpenShift cluster, see https://github.com/openshift/cluster-nfd-operator.

### "Standard" Folder Files

#### tensorflow-buildconfig\_rhel7.yaml and tensorflow-buildconfig\_rhel8.yaml

These yaml files contain templates used for creating a BuildConfig and ImageStream in RHEL 7 and 8, respectively. Both yaml files have parameters `IMAGESTREAM_NAME`, which will be the name of the TensorFlow image when it is saved to your OpenShift instance, and `REGISTRY`, which is the name fo your Docker/CRI-O registry.

#### tensorflow-build-job.yaml

This yaml file contains a template used for calling S2I. It has four parameters: (1.) `IMAGESTREAM_NAME`, (2.) `REGISTRY`, (3.) `APP_NAME`, and (4.) `NAMESPACE`. The first two parameters in this template are the same as the two parameters in the previous template. The third parameter is the name of your app (e.g., `tensorflow-s2i-benchmark-app`) and the fourth parameter is the OpenShift namespace/project you're working on (see `oc project`).

### "NFD" Folder Files

#### tensorflow-nfd-buildconfig\_rhel7.yaml and tensorflow-nfd-buildconfig\_rhel8.yaml

These files are the same as `standard/tensorflow-buildconfig_rhel7.yaml` and `standard/tensorflow-buildconfig_rhel8.yaml`, except they have an added `nodeSelectorTerms` feature to choose whether to build on a node with AVX/AVX2/AVX512. (Note: requires NFD to be installed on your cluster!) There are `tensorflow-buildconfig_rhel7.yaml` and `tensorflow-buildconfig_rhel8.yaml` for each AVX instruction set, including "No AVX."


#### tensorflow-nfd-build-job.yaml

This file is the same as `standard/tensorflow-build-job.yaml`, except with the added `nodeSelectorTerms` feature, much like `nfd/tensorflow-nfd-buildconfig_rhel7.yaml` and `nfd/tensorflow-nfd-buildconfig_rhel8.yaml`. Similar to above, this file exists for each AVX instruction set, including "No AVX."

### "Misc" Folder Files

#### "Volumes"

This folder contains necessary files for creating a PV and PVC for use with an EBS.

#### "Pods"

This folder contains a pod YAML file for creating a dummy pod to populate an EBS.
