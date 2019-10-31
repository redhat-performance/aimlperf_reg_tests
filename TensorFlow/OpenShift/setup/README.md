# Setup

This folder contains files for setting up various things in OpenShift related to the TensorFlow parent folder.

Currently, there are three folders:

  1. `images`
  2. `templates`
  3. `volumes`

The `images` folder contains files for setting up OpenShift to pull images from registry.redhat.io. The `templates` folder loads all the OpenShift templates. Finally, the `volumes` folder contains files for setting up OpenShift to create an EBS for storing NVIDIA related files, such as the cuDNN and NCCL tarballs, such that they can be used for building TensorFlow.

## Images


### registry.redhat.io Images

Create a registry secret file under ../../../../secrets. Follow the instructions on the README. Then run

```
$ make -C images redhat_io_secret
```

### Custom CUDA Images (from ../../Dockerfiles/custom)

#### 1. Create .repo Files for CUDA and RHEL 8

Follow the directions described in `../../../repos/README.md` for creating the necessary `.repo` files.

#### 2. Create 'secrets' files

Follow the directions described in `../../../secrets/README.md` for creating the necessary `redhat_io_registry_password` file and `redhat_io_registry.yaml` file. The former file contains your Docker/Podman login password, which is not to be confused with the OpenShift token provided in the DockerCfg file`redhat_io_registry.yaml`.

#### 3. Run the Makefile

To load the necessary push and pull secrets for registry.redhat.io and your OpenShift Image Registry, as well as build and push the image to the OpenShift Image Registry, run the following "make" command:

```
$ make -C images
```

To confirm the push was successful, you should run `oc get is` and see an output such as:

```
$ oc get is
NAME    IMAGE REPOSITORY                                                                      TAGS                 UPDATED
cuda    default-route-openshift-image-registry.<cluster_url>/openshift-image-registry/cuda    rhel7-with-toolkit   8 minutes ago
```

## Volumes

The first step in creating any `PersistentVolume` or `PersistentVolumeClaim` is to create an EBS volume. You can create one by following the steps in the next subsection.

### Creating an EBS Volume (the Easy Way)

Run `volumes/create_ebs_volume.sh` to create an EBS volume. Call `sh create_ebs_volumes.sh -h` for help on how to use the script. 

### TensorFlow Volumes

Once your EBS volume has been created, grab the **volume ID** and run

```
$ sh volumes/setup_tensorflow_ebs.sh <VOLUME-ID>
```

This will create a TensorFlow PV and TensorFlow PVC based on the EBS volumes.

### ImageNet and NVIDIA Packages

The following instructions pertain to populating EBS volumes with ImageNet data and NVIDIA packages:

Once the EBS volume has been created, create a dummy pod that can be used to save data to the EBS volume by using the `volumes/create_temp_nvidia_pod.sh` script or the `volumes/create_temp_imagenet_pod.sh` script. Both scripts only take in one argument -- the **volume ID** generated from the `create_ebs_volumes.sh` script.

*If* one of the PV/PVC creation scripts fails or otherwise hangs, exit out of the script and call `volumes/force_pv_and_pvc_deletion.sh`. This script takes in only one argument, either: `nvidia` or `imagenet`. The former argument deletes the existing NVIDIA pv and pvc, while the latter deletes the existing ImageNet pv and pvc.
