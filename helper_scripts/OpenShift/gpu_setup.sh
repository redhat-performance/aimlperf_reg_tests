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

# Check if the Special Resource Operator (SRO) git repository already exists. If it exists, delete it.
special_resource_operator_folder=/tmp/special-resource-operator
if [[ -d $special_resource_operator_folder ]]; then
    rm -rf $special_resource_operator_folder
fi

# Clone the operator
git clone https://github.com/zvonkok/special-resource-operator.git $special_resource_operator_folder

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
  echo "Special Resource Operator already deployed. Undeploying to prepare for a redeployment."
  make -C $special_resource_operator_folder undeploy
fi

# Deploy SRO
cd $special_resource_operator_folder/..
make -C special-resource-operator deploy
