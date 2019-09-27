#!/bin/bash
# This script creates a temporary pod that can be used to save data to the EBS device

# The only argument to this script is the ID of the EBS volume
VOLUME_ID=$1

# Set paths to PV, PVC, and pod
NVIDIA_PV_YAML="../../templates/misc/volumes/PersistentVolume_for_nvidia_packages.yaml"
NVIDIA_EBS_YAMLS_FOLDER="../../templates/misc/volumes"
NVIDIA_DUMMY_POD_YAML_FOLDER="../../templates/misc/pods"

# Delete existing PV and PVC
oc delete -f ${NVIDIA_EBS_YAMLS_FOLDER}
oc delete -f ${NVIDIA_DUMMY_POD_YAML_FOLDER}

# Delete existing pod
oc delete pod/tmp-nvidia-pod

# Replace volume ID in ${NVIDIA_PV}
sed -i "s/    volumeID.*/    volumeID: \"${VOLUME_ID}\"/g" ${NVIDIA_PV_YAML}

# Create PV and PVC
oc create -f ${NVIDIA_EBS_YAMLS_FOLDER}

# Create pod
oc create -f ${NVIDIA_DUMMY_POD_YAML_FOLDER}
oc new-app --template=nvidia-ebs-pod
