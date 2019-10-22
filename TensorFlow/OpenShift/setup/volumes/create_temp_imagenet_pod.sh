#!/bin/bash
# This script creates a temporary pod that can be used to save data to the EBS device

# The only argument to this script is the ID of the EBS volume
VOLUME_ID=$1

# Set paths to PV, PVC, and pod
IMAGENET_PV_YAML="../../templates/misc/volumes/PersistentVolume_for_ImageNet.yaml"
IMAGENET_PVC_YAML="../../templates/misc/volumes/PersistentVolumeClaim_for_ImageNet.yaml"
IMAGENET_DUMMY_POD_YAML="../../templates/misc/pods/imagenet_tmp_pod.yaml"

# Print out warning
echo "<< WARNING >> If the deletion of the PV and/or PVC hangs, exit out of this script and call the 'force_pv_and_pvc_deletion.sh' script before running this script again."

# Delete existing PV and PVC
oc delete -f ${IMAGENET_PV_YAML}
oc delete -f ${IMAGENET_PVC_YAML}
oc delete -f ${IMAGENET_DUMMY_POD_YAML}

# Delete existing pod
oc delete pod/tmp-imagenet-pod

# Replace volume ID in ${IMAGENET_PV}
sed -i "s/    volumeID.*/    volumeID: \"${VOLUME_ID}\"/g" ${IMAGENET_PV_YAML}

# Create PV
oc create -f ${IMAGENET_PV_YAML}

# Check status of PV
echo "<< INFO >> Checking status of ImageNet PV..."
pv_capacity_check=""
pv_access_mode_check=""
pv_bound_check=""
pv_available_check=""
min_count=0
sec_count=0
while [[ -z $pv_capacity_check ]] || [[ -z $pv_access_mode_check ]] || [[ -z $pv_available_check ]]; do

    # Update clock counter
    if (( sec_count == 0 )); then
        echo "[${min_count}:00] PV is still initializing"
    else
        echo "[${min_count}:${sec_count}] PV is still initializing"
    fi

    # Get statuses
    oc_get_pv=$(oc get pv/imagenet-pv)
    pv_capacity_check=$(echo $oc_get_pv | grep 100Gi)
    pv_access_mode_check=$(echo $oc_get_pv | grep RWX)
    pv_bound_check=$(echo $oc_get_pv | grep Bound)
    pv_available_check=$(echo $oc_get_pv | grep Available)

    # If the bound check is true, then we have a problem
    if [[ ! -z $pv_bound_check ]]; then
        echo "[${min_count}:00] ERROR. PV is already bound. PVC initialization will hang while PV is bound. Exiting script."
        exit
    fi

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
echo "[${min_count}:${sec_count}] pv/imagenet-pv finished initializing."
echo ""

# Create PVC
oc create -f ${IMAGENET_PVC_YAML}

# Check status of PVC
echo "<< INFO >> Now checking status of ImageNet PVC..."
pvc_capacity_check=""
pvc_access_mode_check=""
pvc_bound_check=""
min_count=0
sec_count=0
while [[ -z $pvc_capacity_check ]] || [[ -z $pvc_access_mode_check ]] || [[ -z $pvc_bound_check ]]; do

    # Update clock counter
    if (( sec_count == 0 )); then
        echo "[${min_count}:00] PVC is still initializing"
    else
        echo "[${min_count}:${sec_count}] PVC is still initializing"
    fi

    # Get statuses
    oc_get_pvc=$(oc get pvc/imagenet-pvc)
    pvc_capacity_check=$(echo $oc_get_pvc | grep 100Gi)
    pvc_access_mode_check=$(echo $oc_get_pvc | grep RWX)
    pvc_bound_check=$(echo $oc_get_pvc | grep Bound)

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
echo "[${min_count}:${sec_count}] PVC finished initializing. PVC is bound to pvc/imagenet-pvc."


# Create pod
oc create -f ${IMAGENET_DUMMY_POD_YAML}
oc new-app --template=imagenet-ebs-pod
