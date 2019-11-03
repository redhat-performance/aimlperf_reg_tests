#!/bin/bash


# Check for git
do_not_have_git=$(which git | grep "which: no")
if [[ ! -z ${do_not_have_git} ]]; then
    echo "Checking for git... NO"
    echo "<< ERROR >> No package for git could be found. Please install 'git'."
    exit 1
fi
echo "Checking for git... YES"

# Check for oc/kubectl
do_not_have_oc=$(which oc | grep "which: no")
do_not_have_kubectl=$(which kubectl | grep "which: no")
if [[ ! -z ${do_not_have_oc} ]] && [[ ! -z ${do_not_have_kubectl} ]]; then
    echo "Checking for oc... NO"
    echo "Checking for kubectl... NO"
    echo "<< ERROR >> No package for oc or kubectl could be found. Please install 'oc' or 'kubectl'."
    exit 1
fi

# Print out status while setting the executable
if [[ -z ${do_not_have_kubectl} ]]; then
    echo "Checking for kubectl... YES"
    executable="kubectl"
fi
if [[ -z ${do_not_have_oc} ]]; then
    echo "Checking for oc... YES"
    executable="oc"
fi

# Check for kubeconfig
if [[ ! -f ${KUBECONFIG} ]]; then
    echo "<< ERROR >> Invalid KUBECONFIG."
    exit 1
fi

# Clone Ripsaw
ripsaw_path=/tmp/ripsaw
mkdir -p ${ripsaw_path}
git clone https://github.com/cloud-bulldozer/ripsaw.git ${ripsaw_path}

# Install operator
cd ${ripsaw_path}
${executable} apply -f resources/namespace.yaml
${executable} project my-ripsaw
${executable} apply -f deploy
${executable} apply -f resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
${executable} apply -f resources/operator.yaml

# Remove ripsaw git repo path
cd ..
rm -rf ${ripsaw_path}
