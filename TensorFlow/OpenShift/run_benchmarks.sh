#!/bin/bash

usage() {
    echo "This script runs the TensorFlow 'models' benchmarks using an s2i image data."
    echo ""
    echo ""
    echo "Usage: $0 [-v rhel_version] [-b backend] [-d number_of_devices] [-s secret_name] [-n] [-t instance_type] [-i custom_imagestream_name] [-a custom_app_name] [-x instruction_set] [-p] [-c gcc_path] [-m memory_size] [-g]"
    echo "  REQUIRED:"
    echo "  -v  Version of RHEL to use. Choose from: {7, 8}."
    echo ""
    echo "  -b  NumPy backend to use with TensorFlow. Choose from: {fftw, openblas}" 
    echo ""
    echo "  -d  Number of devices to use. Must be an integer"
    echo ""
    echo "  -i  The name of the ImageStream to use."
    echo ""
    echo ""
    echo "  REQUIRED FOR RHEL 8 BUILDS and CUDA RHEL 7+8 BUILDS:"
    echo "  -s  Pull secret name for pulling images from registry.redhat.io. (You must have already created and loaded the secret into OpenShift.)"
    echo ""
    echo ""
    echo "  OPTIONAL:"
    echo "  -c  C compiler (gcc). Only usable with RHEL 7 when using the -x argument. (e.g., '/usr/bin/gcc')"
    echo ""
    echo "  -n  Use NFD. (Requires option -i *or* -t to be used!)"
    echo "      -t  Instance type (e.g., m4.4xlarge, m4.large, etc.). Currently cannot be combined with AVX* instructions (this is a TODO)"
    echo "      -x  Use no-AVX, AVX, AVX2, or AVX512 instructions. Choose from: {no_avx, avx, avx2, avx512}. Currently cannot be combined with -i (this is a TODO)"
    echo ""
    echo "  -a  Custom app name (this is what your app will be named). Default: tensorflow-s2i-benchmark-app-rhel7"
    echo ""
    echo "  -p  Use CPU Manager. (Requires options -d and -m to be used!)"
    echo "      -m  Memory size to use with CPU Manager"
    echo ""
    echo "  -u  Use the GPU"
    exit
}

# Set default GPU usage
USE_GPU="false"

# Set vars
templates_path="templates"

options=":h:v:b:t:ns:i:a:x:d:pm:u"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      v)
          RHEL_VERSION=${OPTARG}
          ;;
      b)
          BACKEND=${OPTARG}
          ;;
      n)
          NFD="nfd"
          ;;
      t)
          INSTANCE_TYPE=${OPTARG}
          ;;
      i)
          IS_NAME=${OPTARG}
          ;;
      a)
          APP_NAME=${OPTARG}
          ;;
      x)
          AVX=${OPTARG}
          ;;
      p)
          CPU_MANAGER="true"
          ;;
      m)
          MEMORY_SIZE=${OPTARG}
          ;;
      u)
          USE_GPU="true"
          ;;
      d)
          NUM_DEVICES=${OPTARG}
          ;;
      y)
          NCCL_URL=${OPTARG}
          ;;
      z)
          CUDNN_URL=${OPTARG}
          ;;
      c)
          GCC=${OPTARG}
          ;;
      s)
          SECRET=${OPTARG}
          ;;
      *)
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Check RHEL versioning
if [[ ${RHEL_VERSION} != 7 ]] && [[ ${RHEL_VERSION} != 8 ]]; then
    echo "Invalid version of RHEL. Choose from: {7, 8}"
    exit 1
fi

# Check backend choice
if [[ ${BACKEND} != "fftw" ]] && [[ ${BACKEND} != "openblas" ]]; then
    echo "Invalid backend choice '${BACKEND}'. Choose from: {fftw,openblas}"
    exit 1
elif [[ ${BACKEND} == "openblas" ]] && [[ -z ${USE_GPU} ]]; then
    echo "OpenBLAS backend build job for the CPU is not implemented yet."
    exit 1
fi

# Check if the user specified an image name
if [[ -z ${IS_NAME} ]]; then
    echo "ERROR. ImageStream name missing. Please pass in an argument for the image name with the -i option."
    exit 1
fi

# Check if the imagestream name exists
check_is_name=$(oc get is/${IS_NAME})
if [[ -z ${check_is_name} ]]; then
    echo "ERROR. Provided ImageStream name does not exist. Please build the ImageStream object using 'build_imagestream.sh' or provide a valid ImageStream name."
    exit 1
fi

# Check NFD options
if [[ ${NFD} == "nfd" ]] && [[ ! -z ${AVX} ]] && [[ -z ${INSTANCE_TYPE} ]]; then
    if [[ ${AVX} != "no_avx" ]] && [[ ${AVX} != "avx" ]] && [[ ${AVX} != "avx2" ]] && [[ ${AVX} != "avx512" ]]; then
        echo "Invalid value for -x. Choose from: {no_avx, avx, avx2, avx512}"
        exit 1
    fi
elif [[ ${NFD} == "nfd" ]] && [[ ! -z ${AVX} ]] && [[ ! -z ${INSTANCE_TYPE} ]]; then
    echo "Cannot request instance type and AVX* instructions at the same time."
    exit 1
elif [[ ${NFD} == "nfd" ]] && [[ -z ${AVX} ]] && [[ -z ${INSTANCE_TYPE} ]]; then
    echo "Please specify either AVX instructions or instance type, but not both."
    exit 1
fi

# Check C compiler "GCC" if using RHEL 7
if [[ ${AVX} == "avx512" ]] && [[ -z ${GCC} ]] && [[ ${RHEL_VERSION} == 7 ]]; then
    echo "ERROR. For RHEL 7, please specify a path to gcc with the -c option when using '-x avx512'"
    exit 1
elif [[ -z ${GCC} ]]; then
    GCC="/usr/bin/gcc"
fi

# Check number of devices passed in
if [[ -z ${NUM_DEVICES} ]]; then
    echo "ERROR. Number of devices must be specified with the -d option."
    exit 1
elif [[ ! ${NUM_DEVICES} =~ ^[0-9]+$ ]]; then
    echo "ERROR. Number of devices is not a number. You entered: ${NUM_DEVICES}"
    exit 1
elif (( NUM_DEVICES <= 0 )); then
    echo "ERROR. Number of devices must be a positive number. You entered: ${NUM_DEVICES}"
    exit 1
fi

# Check the instance type, if passed in
if [[ ! -z ${INSTANCE_TYPE} ]]; then

    instance_type_label="beta.kubernetes.io/instance-type=${INSTANCE_TYPE}"
    matching_nodes=$(oc describe node -l $instance_type_label)

    # If the instance type does not exist, throw an error
    if [[ -z ${matching_nodes} ]]; then
        echo "ERROR. No nodes found for instance type ${INSTANCE_TYPE}"
        exit 1
    fi

    # Find the names of the matching nodes
    matching_node_names=$(echo "$matching_nodes" | grep "Name:")

    # All matching nodes are identical, so just grab the first node's name
    first_node=$(echo $matching_node_names | cut -d ' ' -f 2)

    # If the instance type is found, check its CPU count. Note that it doesn't matter *which* node
    # we look at. All the nodes are the same in terms of how many CPUs, etc. they have
    if [[ "${USE_GPU}" == "false" ]]; then

        # Now grab the number of CPUs
        num_cpus=$(oc describe node/"$first_node" | grep "Capacity" -A2 | grep "cpu:" | rev | cut -d' ' -f1 | rev)

        # Check if the CPU count the user entered is less than or equal to the number of CPUs found
        if (( NUM_DEVICES > num_cpus )); then
            echo "ERROR. The number of devices passed in exceeds the number of available devices. You entered $NUM_DEVICES, but the max number of devices for this instance type is $num_cpus."
            exit 1
        fi

    # If the instance type is GPU, then we can't get info on number of GPUs (yet), so let's hardcode some
    elif [[ "${USE_GPU}" == "true" ]]; then 

        # Determine number of GPUs
        if [[ "${INSTANCE_TYPE}" == "p2.xlarge" ]]; then
            num_gpus=1
        elif [[ "${INSTANCE_TYPE}" == "p2.8xlarge" ]]; then
            num_gpus=8
        elif [[ "${INSTANCE_TYPE}" == "p2.16xlarge" ]]; then
            num_gpus=16
	elif [[ "${INSTANCE_TYPE}" == "g3.xlarge" ]]; then
	    num_gpus=1
	elif [[ "${INSTANCE_TYPE}" == "g3.4xlarge" ]]; then
	    num_gpus=1
	elif [[ "${INSTANCE_TYPE}" == "g3.8xlarge" ]]; then
	    num_gpus=2
	elif [[ "${INSTANCE_TYPE}" == "g3.16xlarge" ]]; then
	    num_gpus=4
        else
            num_gpus=444444
            echo "WARNING: Could not determine number of GPUs. Safety check failed. However, this is not an error and the script can continue running."
        fi

        # Check if the GPU count the user entered is less than or equal to the number of GPUs found
        if (( NUM_DEVICES > num_gpus )); then
            echo "ERROR. The number of devices passed in exceeds the number of available devices. You entered $NUM_DEVICES, but the max number of devices for this instance type is $num_gpus."
            exit 1
        fi
    fi
fi

# Check CPU Manager options
if [[ ${CPU_MANAGER} ]] && [[ ${USE_GPU} == "false" ]]; then
    if [[ -z ${MEMORY_SIZE} ]]; then
        echo "ERROR. The CPU Manager option -p was passed, but the memory size (-m) was not specified."
        exit 1
    elif [[ ! ${MEMORY_SIZE} =~ ^[0-9]+G$ ]]; then
        echo "ERROR. Memory size must be in the format of <number>G. You entered: ${MEMORY_SIZE}"
        exit 1
    fi
elif [[ ${CPU_MANAGER} ]] && [[ ${USE_GPU} == "true" ]]; then
    echo "ERROR. Cannot use CPU manager and gpus simultaneously!"
    exit 1
fi

# Initialize app name (if not specified)
if [[ -z ${APP_NAME} ]]; then
    if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
        APP_NAME="tensorflow-benchmarks-rhel${RHEL_VERSION}-${AVX}-cpu-managed"
    elif [[ ! -z ${CPU_MANAGER} ]] && [[ -z ${AVX} ]]; then
        APP_NAME="tensorflow-benchmarks-rhel${RHEL_VERSION}-cpu-managed"
    elif [[ ! -z ${AVX} ]]; then
        APP_NAME="tensorflow-benchmarks-app-rhel${RHEL_VERSION}-${AVX}"
    elif [[ ${USE_GPU} == "true" ]]; then
        APP_NAME="tensorflow-benchmarks-app-rhel${RHEL_VERSION}-gpu"
    else
        APP_NAME="tensorflow-benchmarks-app-rhel${RHEL_VERSION}"
    fi
fi

# Determine benchmarks job template name
if [[ ! -z ${USE_AVX} ]] && [[ -z ${CPU_MANAGER} ]]; then
    benchmarks_job_name="tensorflow-nfd-benchmarks-job-${AVX}"
elif [[ -z ${USE_AVX} ]] && [[ ! -z ${CPU_MANAGER} ]]; then
    benchmarks_job_name="tensorflow-nfd-benchmarks-job-cpu-mgr"
elif [[ ! -z ${USE_AVX} ]] && [[ ! -z ${CPU_MANAGER} ]]; then
    benchmarks_job_name="tensorflow-nfd-benchmarks-job-${AVX}-cpu-mgr"
elif [[ ! -z ${USE_GPU} ]]; then
    benchmarks_job_name="tensorflow-nfd-benchmarks-job-gpu"
elif [[ ! -z ${INSTANCE_TYPE} ]]; then
    benchmarks_job_name="tensorflow-nfd-benchmarks-job"
else
    benchmarks_job_name="tensorflow-benchmarks-job"
fi

# Check if the build job template has been added.
check_job_template=$(oc get templates ${benchmarks_job_name} | grep NAME)
if [[ -z $check_job_template ]]; then
    echo "ERROR. Job template does not exist. Please run 'make -C setup/templates' before running this script."
fi

# Check app name. If the app name already exists, append a number.
check_app_name=$(oc get jobs | grep $APP_NAME)
if [[ ! -z ${check_app_name} ]]; then
    original_app_name=${APP_NAME}
    count=1;
    while [[ ! -z ${check_app_name} ]]; do
        new_app_name="${APP_NAME}-${count}"
	count=$((count+1))
	check_app_name=$(oc get jobs | grep ${new_app_name})
    done
    APP_NAME=${new_app_name}
    echo "WARNING: App name '${original_app_name}' already exists. Rather than deleting ${original_app_name}, the proposed app name '${APP_NAME}' will be used."
fi

if [[ "${NFD}" == "nfd" ]]; then
    if [[ ! -z "${AVX}" ]]; then
        if [[ ! -z "${CPU_MANAGER}" ]]; then
            oc new-app --template="${benchmarks_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=APP_NAME=$APP_NAME \
                       --param=NUM_CPUS=$NUM_DEVICES \
                       --param=N_CPUS=$NUM_DEVICES \
                       --param=MEMORY_SIZE=$MEMORY_SIZE \
		       --param=BACKEND=$BACKEND
        else
            oc new-app --template="${benchmarks_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=APP_NAME=$APP_NAME \
                       --param=NUM_CPUS=$NUM_DEVICES \
		       --param=BACKEND=$BACKEND
        fi
    else
        if [[ ! -z "${CPU_MANAGER}" ]]; then
            oc new-app --template="${benchmarks_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=APP_NAME=$APP_NAME \
                       --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                       --param=NUM_CPUS=$NUM_DEVICES \
                       --param=MEMORY_SIZE=$MEMORY_SIZE \
		       --param=BACKEND=$BACKEND
        elif [[ ${USE_GPU} == "true" ]]; then
            oc new-app --template="${benchmarks_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=APP_NAME=$APP_NAME \
                       --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                       --param=NUM_GPUS=$NUM_DEVICES \
		       --param=BACKEND=$BACKEND
        else
            oc new-app --template="${benchmarks_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=APP_NAME=$APP_NAME \
                       --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                       --param=NUM_CPUS=$NUM_DEVICES \
		       --param=BACKEND=$BACKEND
        fi
    fi
else
    oc new-app --template=$benchmarks_job_name \
               --param=IMAGESTREAM_NAME=$IS_NAME \
               --param=APP_NAME=$APP_NAME \
               --param=NUM_CPUS=$NUM_DEVICES \
	       --param=BACKEND=$BACKEND
fi

# Check the app status
app_running_status=""
app_succeeded_status=""
app_failed_status=""
echo "Checking job status... (This may take up to 6 hours or more depending on the size and type of instance you're using.)"
echo ""
echo "<< WARNING >> Do NOT exit out of this script while it is running. It will stop when it completes."
echo ""
min_count=0
sec_count=0
while [[ -z $app_completed_status ]]; do

    if [[ -z ${first_msg} ]]; then
        first_msg="true"
        echo "[INFO - ${min_count}:00] Job has started"
    fi

    # If the build is running, let the user know
    if [[ ! -z ${app_running_status} ]]; then
        if (( sec_count == 0 )); then
            echo "[INFO - ${min_count}:00] Job is still running"
        else
            echo "[INFO - ${min_count}:${sec_count}] Job is still running"
        fi
    fi

    # Get status of the build
    oc_app_status=$(oc describe job/${APP_NAME} | grep "Pods Statuses")
    app_running_status=$(echo $oc_app_status   | cut -d' ' -f 3 | grep '1')
    app_completed_status=$(echo $oc_app_status | cut -d' ' -f 6 | grep '1')
    app_failed_status=$(echo $oc_app_status    | cut -d' ' -f 9 | grep '1')

    # If the app fails, let the user know
    if [[ ! -z ${app_failed_status} ]]; then
	if (( sec_count == 0 )); then
            echo "[FATAL - ${min_count}:00] App has failed."
	    echo "[FATAL - ${min_count}:00] See 'oc logs job/${APP_NAME}' for debug logs"
	    break
	else
            echo "[FATAL - ${min_count}:${sec_count}] App has failed."
	    echo "[FATAL - ${min_count}:${sec_count}] See 'oc logs job/${APP_NAME}' for debug logs"
	    break
	fi
    fi

    # Update second count
    sec_count=$((sec_count+10))

    # Check if we have 60 seconds. If so, convert seconds to minutes
    if (( sec_count == 60 )); then
        sec_count=0
        min_count=$((min_count+1))
    fi

    # Wait 10 seconds before checking again
    if [[ ! -z $app_running_status ]]; then
        sleep 10
    fi

done

# Print out final app status
if (( sec_count == 0 )); then
    echo "[INFO - ${min_count}:00] App has completed."
else
    echo "[INFO - ${min_count}:${sec_count}] App has completed."
fi

# Get app logs
if (( sec_count == 0 )); then
    echo "[INFO - ${min_count}:00] Checking app logs..."
else
    echo "[INFO - ${min_count}:${sec_count}] Checking app logs..."
fi

time (oc logs job/${APP_NAME}) > app_logs.txt 2> logs_time.txt

# Grep for any failures
job_failed1=$(cat app_logs.txt | grep "failed")    # TensorFlow/playbook fails (e.g., "failed=1")
job_failed2=$(cat app_logs.txt| grep "FAILED! =>") # Playbook fails
job_failed3=$(cat app_logs.txt| grep "Failed")     # TensorFlow fails

# Grep for any errors
job_errors1=$(cat app_logs.txt | grep "ERROR") # TensorFlow/playbook error
job_errors2=$(cat app_logs.txt| grep "error")  # TensorFlow error
job_errors3=$(cat app_logs.txt | grep "Error") # TensorFlow error

# Check if the Ansible output has 'failed=0' in it. If it does, then the job hasn't actually
# failed. The 'failed=0' just means the Ansible status shows that no failures occurred at
# that particular step. But we still need to see if other failures occurred.
job_failed1_ansible_status_check=$(echo ${job_failed1} | grep "failed=0")

# If we found 'failed=0', then let's check if there are any 'failed=1', 'failed=2', etc.
# substrings in the 'job_failed1' string
if [[ ! -z ${job_failed1_ansible_status_check} ]]; then

    # Keep track of the number of failures
    num_failures=0

    # Loop to check the number of failures. At most, we can have 9 the way I've designed 
    # things.
    for c in {0..9}; do
        other_failures_check=$(echo ${job_failed1} | grep "failed=${c}")
	if [[ ! -z ${other_failures_check} ]]; then
	    break
	fi
	num_failures=${c}
    done

    # If there are no failures, then we're okay.
    if (( num_failures == 0 )); then
        job_failed1=""
    fi
fi

# Check if one of the failures is from the installation of FFTW (because there is a part which 
# sometimes throws an error depending on the Podman/Docker image used, but the errors is
# intentionally ignored because the error occurs from an 'ls' command that returns empty, so
# it's not a "real" error; Ansible just *thinks* an empty output is an error).
job_failed2_ignore_check=$(echo ${job_failed2} | grep "...ignoring")
if [[ ! -z ${job_failed2_ignore_check} ]]; then
    job_failed2=""
fi

# A secondary check for the same thing:
if [[ ! -z ${USE_GPU} ]] || [[ ${RHEL_VERSION} == "8" ]]; then
    fftw_install_dir="/opt/app-root/src/custom_fftw"
else
    fftw_install_dir="home/custom_fftw"
fi
job_failed2_ls_check=$(echo ${job_failed2} | grep "ls: cannot access ${fftw_install_dir}/usr: No such file or directory")
if [[ ! -z ${job_failed2_ls_check} ]]; then
    job_failed2=""
fi

log_sec_count=$(cat logs_time.txt | grep "real" | cut -d$'\t' -f2 | cut -d'm' -f 2 | cut -d's' -f 1)
log_sec_count_rounded=$(echo ${sec_count} | awk '{print ($0-int($0)>0)?int($0)+1:int($0)}')
sec_count=$((sec_count+log_sec_count_rounded))
if (( sec_count >= 60 )); then
    sec_count=$((sec_count-60))
    min_count=$((min_count+1))
fi

# If any of the jobs failed or had errors, print them out
if [[ ! -z ${job_failed1} ]] || [[ ! -z ${job_failed2} ]] || [[ ! -z ${job_failed3} ]] || [[ ! -z ${job_errors1} ]] || [[ ! -z ${job_errors2} ]] || [[ ! -z ${job_errors3} ]]; then
    if (( sec_count < 10 )); then
        echo "[FATAL - ${min_count}:0${sec_count}] Job failed."
    else
        echo "[FATAL - ${min_count}:${sec_count}] Job failed."
    fi

    if [[ ! -z ${job_failed1} ]]; then
        if (( sec_count < 10 )); then
            echo "[FATAL - ${min_count}:0${sec_count}] Error msg: ${job_failed1}"
	else
            echo "[FATAL - ${min_count}:${sec_count}] Error msg: ${job_failed1}"
	fi
    fi
    if [[ ! -z ${job_failed2} ]]; then
        if (( sec_count < 10 )); then
            echo "[FATAL - ${min_count}:0${sec_count}] Error msg: ${job_failed2}"
	else
            echo "[FATAL - ${min_count}:${sec_count}] Error msg: ${job_failed2}"
	fi
    fi
    if [[ ! -z ${job_failed3} ]]; then
        if (( sec_count < 10 )); then
            echo "[FATAL - ${min_count}:0${sec_count}] Error msg: ${job_failed3}"
	else
            echo "[FATAL - ${min_count}:${sec_count}] Error msg: ${job_failed3}"
	fi
    fi

    if [[ ! -z ${job_errors1} ]]; then
        if (( sec_count < 10 )); then
            echo "[ERROR - ${min_count}:0${sec_count}] Error msg: ${job_errors1}"
	else
            echo "[ERROR - ${min_count}:${sec_count}] Error msg: ${job_errors1}"
	fi
    fi
    if [[ ! -z ${job_errors2} ]]; then
        if (( sec_count < 10 )); then
            echo "[ERROR - ${min_count}:0${sec_count}] Error msg: ${job_errors2}"
	else
            echo "[ERROR - ${min_count}:${sec_count}] Error msg: ${job_errors2}"
	fi
    fi
    if [[ ! -z ${job_errors3} ]]; then
        if (( sec_count < 10 )); then
            echo "[ERROR - ${min_count}:0${sec_count}] Error msg: ${job_errors3}"
	else
            echo "[ERROR - ${min_count}:${sec_count}] Error msg: ${job_errors3}"
	fi
    fi
fi

# Remove the app logs and timing
rm app_logs.txt logs_time.txt 
