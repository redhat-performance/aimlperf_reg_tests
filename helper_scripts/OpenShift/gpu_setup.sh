#!/bin/bash

# Check for git
do_not_have_git=$(which git | grep "which: no")
if [[ ! -z $do_not_have_git ]]; then
    echo "Checking for git... NO"
    echo "<< ERROR >> No package for git could be found. Please install 'git'."
    exit 1
fi
echo "Checking for git... YES"

# Check for golang
do_not_have_golang=$(which go | grep "which: no")
if [[ ! -z $do_not_have_golang ]]; then
    echo "Checking for Go... NO"
    echo "<< ERROR >> No package for Go could be found. Please install 'golang'."
    exit 1
fi
echo "Checking for Go... YES"

# Clone Cluster NFD Operator
cluster_nfd_operator_folder=/tmp/cluster-nfd-operator
if [[ ! -d $cluster_nfd_operator_folder ]]; then
    git clone https://github.com/openshift/cluster-nfd-operator $cluster_nfd_operator_folder
else

    # Check for namespaces
    nfd_operator_ns_check=$(oc get namespace/openshift-nfd-operator)

    # Check for service accounts
    nfd_operator_sa_check=$(oc get serviceaccount/nfd-operator)

    # Determine if these resources exist
    nfd_operator_ns_message=$(echo $nfd_operator_ns_check | grep "not found")
    nfd_operator_sa_message=$(echo $nfd_operator_sa_check | grep "not found")
    if [[ -z $nfd_operator_ns_message ]] || [[ -z $nfd_operator_sa_message ]]; then
        echo "Cluster NFD operator already deployed. Undeploying to prepare for a redeployment."
        make -C $cluster_nfd_operator_folder undeploy
    fi
fi
cd $cluster_nfd_operator_folder/..
make -C cluster-nfd-operator deploy

# Clone special resource operator
special_resource_operator_folder=/tmp/special-resource-operator
if [[ ! -d $special_resource_operator_folder ]]; then
    git clone https://github.com/zvonkok/special-resource-operator $special_resource_operator_folder
else

    # Check for namespaces
    special_resource_operator_ns_check=$(oc get namespace/openshift-sro-operator)
    special_resource_ns_check=$(oc get namespace/openshift-sro)

    # Check for service accounts
    special_resource_sa_check=$(oc get serviceaccount/sro-operator)

    # Determine if these resources exist
    special_resource_operator_ns_message=$(echo $special_resource_operator_ns_check | grep "not found")
    special_resource_ns_message=$(echo $special_resource_ns_check | grep "not found")
    special_resource_operator_sa_message=$(echo $special_resource_operator_sa_check | grep "not found")
    if [[ -z $special_resource_operator_ns_message ]] || [[ -z $special_resource_operator_sa_message ]] || [[ -z $special_resource_ns_message ]]; then
        echo "Cluster NFD operator already deployed. Undeploying to prepare for a redeployment."
        make -C $special_resource_operator_folder undeploy
    fi
fi
cd $special_resource_operator_folder/..
make -C special-resource-operator deploy
