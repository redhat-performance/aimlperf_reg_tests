#!/bin/bash

usage() {
    echo "This script disables cpumanager for a given node"
    echo ""
    echo "Usage: $0 [-n node_name] [-x avx_instruction_set] [-i use_custom_instance]"
    echo "  REQUIRED:"
    echo "  -n  Node name."
    echo ""
    echo "  OPTIONAL (choose 1):"
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
      *)
          usage
          ;;
    esac
done


# Label node
oc label node/${NODE_NAME} cpumanager-

# Add label to machineconfigpool worker
oc label machineconfigpool/worker custom-kubelet-

# Create the dynamic KubeletConfig
if [[ ! -z ${AVX} ]] && [[ ${INSTANCE} == "true" ]]; then
    echo "ERROR. Cannot use -x and -i together. Choose one or the other."
    exit 1
elif [[ ! -z ${AVX} ]]; then
    kubeletconfig_path="../templates/nfd/instruction_sets/kubeletconfig/cpumanager-kubeletconfig.yaml"
elif [[ ${INSTANCE} == "true" ]]; then
    kubeletconfig_path="../templates/nfd/instance/kubeletconfig/cpumanager-kubeletconfig.yaml"
else
    echo "ERROR. Must use -x or -i."
    exit 1
fi
oc delete -f ${kubeletconfig_path}
