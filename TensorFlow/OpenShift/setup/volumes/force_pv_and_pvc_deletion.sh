#!/bin/bash

#################################################################
# This script forces a PV and PVC deletion when OpenShift hangs #
#################################################################

# Patch the PVC
oc patch pvc nvidia-packages-pvc -p '{"metadata":{"finalizers":null}}'

# Delete the PVC
oc delete pvc nvidia-packages-pvc

# Patch the PV
oc patch pv nvidia-packages-pv -p '{"metadata":{"finalizers":null}}'

# Sleep
echo "Sleeping for 10 seconds..."
sleep 10

# Now delete the PV
oc delete pv nvidia-packages-pv
