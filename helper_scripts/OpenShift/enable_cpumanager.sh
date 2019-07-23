#!/bin/bash

usage() {
    echo "This script enables cpumanager for a given node"
    echo ""
    echo "Usage: $0 [-n node_name] [-x avx_instruction_set] [-i use_custom_instance]"
    echo "  REQUIRED:"
    echo "  -n  Node name."
    echo "  -k  Path to KubeletConfig file"
    echo ""
    echo "  CHOOSE ONE:"
    echo "  -x  Use AVX instructions. Choose from: {no_avx, avx, avx2, avx512}"
    echo "  -i  Use instance type."
    exit
}

options=":h:n:x:i"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      n)
          NODE_NAME=${OPTARG}
          ;;
      x)
          AVX=${OPTARG}
          ;;
      i)
          INSTANCE="true"
          ;;
      k)
          KUBELET_CONFIG=${OPTARG}
          ;;
      *)
          usage
          ;;
    esac
done


# Label node
oc label node/${NODE_NAME} cpumanager=true --overwrite=true

# Add label to machineconfigpool worker
oc label machineconfigpool/worker custom-kubelet=cpumanager-enabled

# Create the dynamic KubeletConfig
if [[ ! -z ${AVX} ]] && [[ ${INSTANCE} == "true" ]]; then
    echo "ERROR. Cannot use -x and -i together. Choose one or the other."
    exit 1
elif [[ -z ${AVX} ]] && [[ -z ${INSTANCE} ]]; then
    echo "ERROR. Must use -x or -i."
    exit 1
else
    kubeletconfig_path=${KUBELET_CONFIG}
fi
oc create -f ${kubeletconfig_path}
