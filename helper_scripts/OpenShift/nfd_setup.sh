#!/bin/bash
# This script sets up NFD operator

# Set which version of OCP
OCP_VERSION=$1

# Check if OCP_VERSION was passed in
if [[ -z ${OCP_VERSION} ]]; then
    echo "ERROR. Please pass in an OCP version."
    exit 1
fi

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
git checkout release-${OCP_VERSION}
make deploy

# Remove Cluster NFD Operator
rm -rf ${CLUSTER_NFD_OPERATOR}
