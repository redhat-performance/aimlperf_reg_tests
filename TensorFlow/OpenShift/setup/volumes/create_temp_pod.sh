#!/bin/bash
# This script creates a temporary pod that can be used to save data to the EBS device

# The only argument to this script is the ID of the EBS volume
VOLUME_ID=$1

# Set paths to PV, PVC, and pod
NVIDIA_PV_YAML="../../templates/misc/volumes/PersistentVolume_for_nvidia_packages.yaml"
NVIDIA_PVC_YAML="../../templates/misc/volumes/PersistentVolumeClaim_for_nvidia_packages.yaml"
NVIDIA_DUMMY_POD_YAML_FOLDER="../../templates/misc/pods"

# Print out warning
echo "<< WARNING >> If the deletion of the PV and/or PVC hangs, exit out of this script and call the 'force_pv_and_pvc_deletion.sh' script before running this script again."

# Delete existing PV and PVC
oc delete -f ${NVIDIA_PV_YAML}
oc delete -f ${NVIDIA_PVC_YAML}
oc delete -f ${NVIDIA_DUMMY_POD_YAML_FOLDER}

# Delete existing pod
oc delete pod/tmp-nvidia-pod

# Replace volume ID in ${NVIDIA_PV}
sed -i "s/    volumeID.*/    volumeID: \"${VOLUME_ID}\"/g" ${NVIDIA_PV_YAML}

# Create PV
oc create -f ${NVIDIA_PV_YAML}

# Check status of PV
echo "<< INFO >> Checking status of PV..."
pv_capacity_check=""
pv_access_mode_check=""
pv_bound_check=""
min_count=0
sec_count=0
while [[ -z $pv_capacity_check ]] || [[ -z $pv_access_mode_check ]] || [[ -z $pv_bound_check ]]; do

    # Update clock counter
    if (( sec_count == 0 )); then
        echo "[${min_count}:00] PV is still initializing"
    else
        echo "[${min_count}:${sec_count}] PV is still initializing"
    fi

    # Get statuses
    oc_get_pv=$(oc get pv/nvidia-packages-pv)
    pv_capacity_check=$(echo $oc_get_pv | grep 50Gi)
    pv_access_mode_check=$(echo $oc_get_pv | grep RWX)
    pv_bound_check=$(echo $oc_get_pv | grep Bound)

    # Update second count
    sec_count=$((sec_count+10))

    # Check if we have 60 seconds. If so, convert seconds to minutes
    if (( $sec_count == 60 )); then
        sec_count=0
        min_count=$((min_count+1))
    fi

    # Wait 10 seconds before checking again
    sleep 10

done 
echo "[${min_count}:${sec_count}] PV finished initializing."
echo ""

# Create PVC
oc create -f ${NVIDIA_PVC_YAML}

# Check status of PVC
echo "<< INFO >> Now checking status of PVC..."
pvc_capacity_check=""
pvc_access_mode_check=""
pvc_ready_check=""
min_count=0
sec_count=0
while [[ -z $pvc_capacity_check ]] || [[ -z $pvc_access_mode_check ]] || [[ -z $pvc_ready_check ]]; do

    # Update clock counter
    if (( sec_count == 0 )); then
        echo "[${min_count}:00] PVC is still initializing"
    else
        echo "[${min_count}:${sec_count}] PVC is still initializing"
    fi

    # Get statuses
    oc_get_pvc=$(oc get pvc/nvidia-packages-pvc)
    pvc_capacity_check=$(echo $oc_get_pvc | grep 50Gi)
    pvc_access_mode_check=$(echo $oc_get_pvc | grep RWX)
    pvc_ready_check=$(echo $oc_get_pvc | grep Ready)

    # Update second count
    sec_count=$((sec_count+10))

    # Check if we have 60 seconds. If so, convert seconds to minutes
    if (( $sec_count == 60 )); then
        sec_count=0
        min_count=$((min_count+1))
    fi

    # Wait 10 seconds before checking again
    sleep 10

done 
echo "[${min_count}:${sec_count}] PVC finished initializing."


# Create pod
oc create -f ${NVIDIA_DUMMY_POD_YAML_FOLDER}
oc new-app --template=nvidia-ebs-pod
