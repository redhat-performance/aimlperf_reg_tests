#!/bin/bash

# EBS type must be either 'nvidia' or 'imagenet'
EBS_TYPE=$1

if [[ -z ${EBS_TYPE} ]]; then
    echo "ERROR. Please pass in an EBS type, either: 'nvidia' or 'imagenet'."
    exit 1
elif [[ ${EBS_TYPE} != "nvidia" ]] && [[ ${EBS_TYPE} != "imagenet" ]]; then
    echo "ERROR. Invalid EBS type '${EBS_TYPE}'. Please use either 'nvidia' or 'imagenet'."
    exit 1
elif [[ ${EBS_TYPE} == "nvidia" ]]; then
    PVC="nvidia-packages-pvc"
    PV="nvidia-packages-pv"
else
    PVC="imagenet-pvc"
    PV="imagenet-pv"
fi

#################################################################
# This script forces a PV and PVC deletion when OpenShift hangs #
#################################################################

# Patch the PVC
oc patch pvc ${PVC} -p '{"metadata":{"finalizers":null}}'

# Delete the PVC
oc delete pvc ${PVC}

# Patch the PV
oc patch pv ${PV} -p '{"metadata":{"finalizers":null}}'

# Sleep
echo "Sleeping for 10 seconds..."
sleep 10

# Now delete the PV
oc delete pv ${PV}
