#!/bin/bash
# This script sets up NFD operator

# Set environment vars
CLUSTER_NFD_OPERATOR=/tmp/cluster-nfd-operator

# Check if ${CLUSTER_NFD_OPERATOR} directory already exists
if [[ -d ${CLUSTER_NFD_OPERATOR} ]]; then
    rm -rf ${CLUSTER_NFD_OPERATOR}
fi

# Download Cluster NFD Operator from git via 'git clone'
git clone https://github.com/openshift/cluster-nfd-operator.git ${CLUSTER_NFD_OPERATOR}

# Add Cluster NFD Operator to cluster
cd ${CLUSTER_NFD_OPERATOR}
make deploy

# Remove Cluster NFD Operator
rm -rf ${CLUSTER_NFD_OPERATOR}
