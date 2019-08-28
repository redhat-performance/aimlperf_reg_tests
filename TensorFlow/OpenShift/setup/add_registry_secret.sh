#!/bin/bash
# This script adds a registry secret

# User (optionally) passes in the path to the registry secret; default is '../../secrets/redhat_io_secret.yaml
REGISTRY_SECRET_FILE=$1
if [[ -z ${REGISTRY_SECRET_FILE} ]]; then
    REGISTRY_SECRET_FILE="../../../secrets/redhat_io_registry.yaml"
fi

# Now, add the secret
oc create -f "${REGISTRY_SECRET_FILE}" --namespace=openshift-image-registry

# Get pull secret name
while IFS=" " read -r t || [ -n "$t" ]
do
   if [[ ${t} == "name:"* ]]; then
       found_name="true"
       pull_secret="$(echo ${t} | cut -d ' ' -f 2)"
       break
   fi
done < "${REGISTRY_SECRET_FILE}"

# Check if name was found
if [[ -z "${found_name}" ]]; then
    echo "ERROR. Could not find pull secret name. Is this a valid file?"
    exit 1
fi

# Update the image pull secrets
oc secrets add serviceaccount/default secrets/"${pull_secret}" --for=pull
