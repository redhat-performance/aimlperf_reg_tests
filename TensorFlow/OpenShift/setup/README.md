# Setup

This folder contains files for setting up various things in OpenShift related to the TensorFlow parent folder.

Currently, there are two folders:

  1. `images`
  2. `volumes`

The `images` folder contains files for setting up OpenShift to pull images from registry.redhat.io, while the `volumes` folder contains files for setting up OpenShift to create an EBS for storing NVIDIA related files, such as the cuDNN and NCCL tarballs, such that they can be used for building TensorFlow.

## Images

Run `add_registry_secret.sh` to add your redhat.io registry secret to OpenShift. Make sure you have a registry secret already added to the top level `secrets` folder in this repository. See the main `../OpenShift/README.md` file for more information.

## Volumes

Run `create_ebs_volume.sh` to create an EBS volume. Call `sh create_ebs_volumes.sh -h` for help on how to use the script. 

Once the EBS volume has been created, create a dummy pod that can be used to save data to the EBS volume by using the `create_temp_pod.sh` script. It only takes in one argument -- the **volume ID** generated from the `create_ebs_volumes.sh` script.
