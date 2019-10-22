#!/bin/bash

usage() {
    echo "This script launches the TensorFlow CNN High-Performance benchmark app on an AWS OpenShift cluster for RHEL 7 only (for now). Node Feature Discovery may optionally be used for selecting specific nodes, and CPU Manager may optionally be used as well."
    echo ""
    echo ""
    echo "Usage: $0 [-v rhel_version] [-b backend] [-d number_of_devices] [-s secret_name] [-n] [-t instance_type] [-r image_registry] [-e namespace] [-i custom_imagestream_name] [-a custom_app_name] [-x instruction_set] [-p] [-c gcc_path] [-m memory_size] [-g]"
    echo "  REQUIRED:"
    echo "  -v  Version of RHEL to use. Choose from: {7, 8}."
    echo ""
    echo "  -b  NumPy backend to use with TensorFlow. Choose from: {fftw, openblas}" 
    echo ""
    echo "  -d  Number of devices to use. Must be an integer"
    echo ""
    echo ""
    echo "  REQUIRED FOR RHEL 8 BUILDS:"
    echo "  -s  Pull secret name for pulling images from registry.redhat.io. (You must have already created and loaded the secret into OpenShift.)"
    echo ""
    echo ""
    echo "  OPTIONAL:"
    echo "  -c  C compiler (gcc). Only usable with RHEL 7 when using the -x argument. (e.g., '/usr/bin/gcc')"
    echo ""
    echo "  -n  Use NFD. (Requires option -i *or* -x to be used!)"
    echo "      -i  Custom ImageStream name (this is what your image will be named). Default: fftw-rhel<rhel-version>"
    echo "      -x  Use no-AVX, AVX, AVX2, or AVX512 instructions. Choose from: {no_avx, avx, avx2, avx512}. Currently cannot be combined with -i (this is a TODO)"
    echo ""
    echo "  -t  Instance type (e.g., m4.4xlarge, m4.large, etc.). Currently cannot be combined with AVX* instructions (this is a TODO)"
    echo ""
    echo "  -r  OpenShift Image Registry URL (e.g., image-registry.openshift-image-registry.svc:5000). If you do not use this flag, the registry defaults whatever \"oc registry info\" outputs."
    echo ""
    echo "  -e  Namespace to use"
    echo ""
    echo "  -a  Custom app name (this is what your app will be named). Default: tensorflow-s2i-benchmark-app-rhel7"
    echo ""
    echo "  -p  Use CPU Manager. (Requires options -d and -m to be used!)"
    echo "      -m  Memory size to use with CPU Manager"
    echo ""
    echo "  -u  Use GPUs (Requires option -t, -d, -y, and -z to be used!)"
    echo "      -y  NCCL download URL or s3 bucket path"
    echo "      -z  cuDNN download URL or s3 bucket path"
    echo ""
    echo "  -o  Use AWS for downloading cuDNN and NCCL. (Currently, either use AWS for downloading both or don't use AWS at all. This is a TODO.)"
    echo "      -j  AWS access key"
    echo "      -k  AWS secret access key"
    echo "      -l  AWS region"
    echo "      -q  AWS profile name"
    echo ""
    echo "  -f  Use EBS for getting NCCL and cuDNN"
    exit
}

# Set default GPU usage
USE_GPU="false"

# Set vars
templates_path="templates"

options=":h:v:b:t:nr:s:i:a:x:d:pm:l:ug:y:z:c:oj:k:l:q:f"
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
      r)
          OC_REGISTRY=${OPTARG}
          ;;
      e)
          NAMESPACE=${OPTARG}
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
      o)
          USE_AWS="true"
          ;;
      j)
          AWS_ACCESS_KEY=${OPTARG}
          ;;
      k)
          AWS_SECRET_ACCESS_KEY=${OPTARG}
          ;;
      l)
          AWS_REGION=${OPTARG}
          ;;
      q)
          AWS_PROFILE_NAME=${OPTARG}
          ;;
      f)
          USE_EBS="true"
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
elif [[ ${BACKEND} == "openblas" ]]; then
    echo "OpenBLAS backend build not implemented yet."
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

# Check GPU options
if [[ ${USE_GPU} == "true" ]]; then

    # Check if using AWS
    if [[ ! -z ${USE_AWS} ]]; then
        if [[ -z ${AWS_ACCESS_KEY} ]]; then
            echo "ERROR. The -o option was passed in to use AWS, but no access key was provided. Please provide an access key with the -j option."
            exit 1
        elif [[ -z ${AWS_SECRET_ACCESS_KEY} ]]; then
            echo "ERROR. The -o option was passed in to use AWS and an AWS access key was provided, but no secret access key was provided. Please provide a secret access key with the -k option."
            exit 1
        elif [[ -z ${AWS_REGION} ]]; then
            echo "ERROR. The -o option was passed in to use AWS and both the AWS access and secret access keys were provided, but a region was not provided. Please provide a region using the -l option."
            exit 1
        elif [[ -z ${AWS_PROFILE_NAME} ]]; then
            echo "ERROR. The -o option was passed in to use AWS and all required arguments were provided except for the AWS profile name. Please provide a profile name with the -q option."
            exit 1
        fi
    fi

    # Make sure that the user didn't pass in more than one NCCL/cuDNN acquire method
    if [[ ! -z ${USE_AWS} ]] && [[ ! -z ${USE_EBS} ]]; then
        echo "ERROR. Cannot use AWS and EBS at the same time. Please choose one or the other."
        exit 1
    fi

    # Make sure the user passed in a download URL or s3 bucket folder for NCCL if not using EBS
    if [[ -z ${NCCL_URL} ]] && [[ -z ${USE_EBS} ]]; then
        echo "ERROR. NCCL download URL or s3 bucket folder name is missing. Please provide an NCCL URL or s3 bucket with the -y option."
        exit 1
    fi

    # Do the same with cuDNN if not using EBS
    if [[ -z ${CUDNN_URL} ]] && [[ -z ${USE_EBS} ]]; then
        echo "ERROR. cuDNN download URL or s3 bucket folder name is missing. Please provide a cuDNN URL or s3 bucket with the -z option."
        exit 1
    fi
fi

# Initialize image name (if not specified)
if [[ -z ${IS_NAME} ]]; then

    # For RHEL 8...
    if [[ ${RHEL_VERSION} == 8 ]]; then
        if [[ ! -z ${AVX} ]]; then
            IS_NAME="tensorflow-${BACKEND}-rhel8-${AVX}"
        elif [[ ${USE_GPU} == "true" ]]; then
            IS_NAME="tensorflow-${BACKEND}-rhel8-gpu"
        else
            IS_NAME="tensorflow-${BACKEND}-rhel8"
        fi

    # Otherwise, for RHEL 7...
    else
        if [[ ! -z ${AVX} ]]; then
            IS_NAME="tensorflow-${BACKEND}-rhel7-${AVX}"
        elif [[ ${USE_GPU} == "true" ]]; then
            IS_NAME="tensorflow-${BACKEND}-rhel7-gpu"
        else
            IS_NAME="tensorflow-${BACKEND}-rhel7"
        fi
    fi
fi

# Initialize app name (if not specified)
if [[ -z ${APP_NAME} ]]; then
    if [[ ${RHEL_VERSION} == 8 ]]; then
        if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel8-${AVX}-cpu-managed"
        elif [[ ! -z ${AVX} ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel8-${AVX}"
        elif [[ ${USE_GPU} == "true" ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel8-gpu"
        else
            APP_NAME="tensorflow-s2i-benchmark-app-rhel8"
        fi
    else
        if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel7-${AVX}-cpu-managed"
        elif [[ ! -z ${AVX} ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel7-${AVX}"
        elif [[ ${USE_GPU} == "true" ]]; then
            APP_NAME="tensorflow-s2i-benchmark-app-rhel7-gpu"
        else
            APP_NAME="tensorflow-s2i-benchmark-app-rhel7"
        fi
    fi
fi
if [[ -z ${OC_REGISTRY} ]]; then 
     OC_REGISTRY="image-registry.openshift-image-registry.svc:5000"
fi
if [[ -z ${NAMESPACE} ]]; then
    NAMESPACE=$(oc project | cut -d" " -f3 | cut -d'"' -f2)
else
    existing_namespaces=$(oc projects | grep -w ${NAMESPACE})
    if [[ -z ${existing_namespaces} ]]; then
        echo "ERROR. Namespace \"${NAMESPACE}\" does not exist."
        exit 1
    fi
fi

# Determine build image template name
if [[ ! -z ${USE_AVX} ]]; then
    build_image_template_name="tensorflow-${BACKEND}-${AVX}-build-image-rhel${RHEL_VERSION}"
elif [[ ! -z ${USE_GPU} ]]; then
    build_image_template_name="tensorflow-${BACKEND}-build-image-rhel${RHEL_VERSION}-gpu"
else
    build_image_template_name="tensorflow-${BACKEND}-build-image-rhel${RHEL_VERSION}"
fi

# Determine build image template filename
if [[ ! -z ${USE_AVX} ]]; then
    build_image_template_file="${templates_path}/nfd/instruction_sets/${AVX}/buildconfig/tensorflow-${BACKEND}-nfd-buildconfig-rhel${RHEL_VERSION}.yaml"
elif [[ ! -z ${USE_GPU} ]]; then
    build_image_template_file="${templates_path}/nfd/instance/buildconfig/tensorflow-${BACKEND}-buildconfig-rhel${RHEL_VERSION}-gpu.yaml"
elif [[ ! -z ${INSTANCE_TYPE} ]]; then
    build_image_template_file="${templates_path}/nfd/instance/buildconfig/tensorflow-${BACKEND}-buildconfig-rhel${RHEL_VERSION}.yaml"
else
    build_image_template_file="${templates_path}/standard/tensorflow-${BACKEND}-buildconfig-rhel${RHEL_VERSION}.yaml"
fi

# Determine build job template name
if [[ ! -z ${USE_AVX} ]]; then
    build_job_name="tensorflow-${AVX}-nfd-build-job"
elif [[ ! -z ${USE_GPU} ]]; then
    build_job_name="tensorflow-nfd-build-job-gpu"
elif [[ ! -z ${CPU_MANAGER} ]]; then
    build_job_name="tensorflow-nfd-cpu-manager-build-job"
elif [[ ! -z ${INSTANCE_TYPE} ]]; then
    build_job_name="tensorflow-nfd-build-job"
else
    build_job_name="tensorflow-build-job"
fi

# Determine build job template filename
if [[ ! -z ${USE_AVX} ]]; then
    if [[ ! -z ${CPU_MANAGER} ]]; then
        build_job_path="${templates_path}/nfd/insruction_sets/${AVX}/job/cpu_manager/tensorflow-nfd-build-job.yaml"
    else
        build_job_path="${templates_path}/nfd/instruction_sets/${AVX}/job/default/tensorflow-nfd-build-job.yaml"
    fi
elif [[ ! -z ${USE_GPU} ]]; then
    build_job_path="${templates_path}/nfd/instance/job/gpu/tensorflow-nfd-build-job.yaml"
elif [[ ! -z ${INSTANCE_TYPE} ]]; then
    if [[ ! -z ${CPU_MANAGER} ]]; then
        build_job_path="${templates_path}/nfd/instance/job/cpu_manager/tensorflow-nfd-build-job.yaml"
    else
        build_job_path="${templates_path}/nfd/instance/job/default/tensorflow-nfd-build-job.yaml"
    fi
else
    build_job_path="${templates_path}/standard/tensorflow-build-job.yaml"
fi

# Check if the build template already exists. If it does, delete it and re-create it
check_build_template=$(oc get templates ${build_image_template_name} | grep NAME)
if [[ ! -z $check_build_template ]]; then
    oc delete -f "${build_image_template_file}"
fi
oc create -f ${build_image_template_file}

# Do the same with the build job
check_job_template=$(oc get templates ${build_job_name} | grep NAME)
if [[ ! -z $check_job_template ]]; then
    oc delete -f ${build_job_path}
fi
oc create -f ${build_job_path}

# Check build configs
check_bc=$(oc get bc ${build_image_template_name} | grep NAME)
if [[ ! -z $check_bc ]]; then
    oc delete bc ${build_image_template_name}
fi

# Check image streams
check_imagestream=$(oc get is $IS_NAME | grep NAME)
if [[ ! -z $check_imagestream ]]; then
    oc delete is $IS_NAME
fi

# Build the image
check_existing_builds=$(oc get builds | grep ${build_image_template_name})
if [[ ! -z $check_existing_builds ]]; then
oc delete build "${build_image_template_name}-1"
fi
if [[ ! -z ${NFD} ]]; then
    if [[ ! -z "${AVX}" ]]; then
        if [[ "${RHEL_VERSION}" == "7" ]]; then
            oc new-app --template="${build_image_template_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY
        else
            oc new-app --template="${build_image_template_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=PULL_SECRET=$SECRET
        fi
    else
        oc new-app --template="${build_image_template_name}" \
                   --param=IMAGESTREAM_NAME=$IS_NAME \
                   --param=REGISTRY=$OC_REGISTRY \
                   --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                   --param=PULL_SECRET=$SECRET
    fi
else
    oc new-app --template="${build_image_template_name}" --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY
fi
oc start-build ${build_image_template_name}

# Build the app
check_existing_jobs=$(oc get jobs | grep $APP_NAME)
if [[ ! -z $check_existing_jobs ]]; then
    oc delete job $APP_NAME
fi

build_succeeded_status=""
build_completed_status=""
build_failed_status=""
build_stopped_status=""
build_pending_status=""
echo "Checking build status... (This may take up to 15 minutes or more depending on the size and type of instance you're using.)"
echo ""
echo "<< WARNING >> Do NOT exit out of this script while it is running. It will stop when it completes."
echo ""
min_count=0
sec_count=0
while [[ -z $build_succeeded_status ]] && [[ -z $build_failed_status ]] && [[ -z $build_stopped_status ]] && [[ -z $build_completed_status ]]; do

    # Update clock counter by first letting the user know the build is pending
    if (( sec_count == 0 )) && (( min_count == 0 )); then
        echo "[INFO - 0:00] Build is pending"

    # If the build is still pending, then let the user know
    elif [[ ! -z ${build_pending_status} ]]; then
        if (( sec_count == 0 )); then
            echo "[INFO - ${min_count}:00] Build is still pending"
        else
            echo "[INFO - ${min_count}:${sec_count}] Build is still pending"
        fi

    # If the build is running, then let the user know
    else
        if (( sec_count == 0 )); then
            if [[ ! -z ${build_started} ]] && [[ ! -z ${first_msg} ]]; then
                echo "[INFO - ${min_count}:00] Build is still running"
            else
                first_msg="true"
                echo "[INFO - ${min_count}:00] Build has started"
            fi
        else
            if [[ ! -z ${build_started} ]] && [[ ! -z ${first_msg} ]]; then
                echo "[INFO - ${min_count}:${sec_count}] Build is still running"
            else
                first_msg="true"
                echo "[INFO - ${min_count}:${sec_count}] Build has started"
            fi
        fi
    fi

    # Get status of the build
    oc status > statuses.txt 
    oc_build_status=$(grep -i -A 1 "  -> istag/${IS_NAME}:latest" statuses.txt)
    build_succeeded_status=$(echo $oc_build_status | grep build | grep succeeded)
    build_completed_status=$(echo $oc_build_status | grep build | grep completed)
    build_failed_status=$(echo $oc_build_status | grep build | grep failed)
    build_stopped_status=$(echo $oc_build_status | grep build | grep stopped)
    build_pending_status=$(echo $oc_build_status | grep build | grep pending)

    # Figure out when build is finally running
    if [[ -z ${build_pending_status} ]] && [[ -z ${build_started} ]]; then
        build_started="true"
    fi

    # Update second count
    sec_count=$((sec_count+10))

    # Check if we have 60 seconds. If so, convert seconds to minutes
    if (( $sec_count == 60 )); then
        sec_count=0
        min_count=$((min_count+1))
    fi

    # Wait 10 seconds before checking again
    if [[ -z $build_succeeded_status ]] && [[ -z $build_completed_status ]]; then
        sleep 10
    fi

done

if [[ ! -z $build_failed_status ]]; then
    if (( sec_count == 0 )); then
        echo "[FATAL - ${min_count}:00 ] Image build FAILED, so build job will not run."
    else
        echo "[FATAL - ${min_count}:${sec_count} ] Image build FAILED, so build job will not run."
    fi
elif [[ ! -z $build_stopped_status ]]; then
    if (( sec_count == 0 )); then
        echo "[FATAL - ${min_count}:00 ] Image build STOPPED, so build job will not run."
    else
        echo "[FATAL - ${min_count}:${sec_count} ] Image build STOPPED, so build job will not run."
    fi
elif [[ "${NFD}" == "nfd" ]]; then
    if [[ ! -z "${AVX}" ]]; then
        if [[ ! -z "${CPU_MANAGER}" ]]; then
            oc new-app --template="${build_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=APP_NAME=$APP_NAME \
                       --param=NAMESPACE=$NAMESPACE \
                       --param=RHEL_VERSION=$RHEL_VERSION \
                       --param=NUM_CPUS=$NUM_DEVICES \
                       --param=N_CPUS=$NUM_DEVICES \
                       --param=MEMORY_SIZE=$MEMORY_SIZE \
                       --param=CC=$GCC
        else
            oc new-app --template="${build_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=APP_NAME=$APP_NAME \
                       --param=NAMESPACE=$NAMESPACE \
                       --param=RHEL_VERSION=$RHEL_VERSION \
                       --param=NUM_CPUS=$NUM_DEVICES \
                       --param=CC=$GCC
        fi
    else
        if [[ ! -z "${CPU_MANAGER}" ]]; then
            if [[ -z ${THREAD_VALUES} ]]; then
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=RHEL_VERSION=$RHEL_VERSION \
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE \
                           --param=CC=$GCC
            else
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=RHEL_VERSION=$RHEL_VERSION \
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE \
                           --param=THREAD_VALUES=$THREAD_VALUES \
                           --param=CC=$GCC
            fi
        elif [[ ${USE_GPU} == "true" ]]; then
            if [[ ${USE_AWS} == "true" ]]; then
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=RHEL_VERSION=$RHEL_VERSION \
                           --param=NUM_GPUS=$NUM_DEVICES \
                           --param=NCCL_URL=$NCCL_URL \
                           --param=CUDNN_URL=$CUDNN_URL \
                           --param=CC=$GCC \
                           --param=AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
                           --param=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                           --param=AWS_REGION=$AWS_REGION \
                           --param=AWS_PROFILE=$AWS_PROFILE_NAME \
                           --param=WHICH_SOURCE="s3"
            elif [[ ! -z ${USE_EBS} ]]; then
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=RHEL_VERSION=$RHEL_VERSION \
                           --param=NUM_GPUS=$NUM_DEVICES \
                           --param=CC=$GCC \
                           --param=WHICH_SOURCE="ebs"
            else
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=RHEL_VERSION=$RHEL_VERSION \
                           --param=NUM_GPUS=$NUM_DEVICES \
                           --param=NCCL_URL=$NCCL_URL \
                           --param=CUDNN_URL=$CUDNN_URL \
                           --param=CC=$GCC
            fi
        else
            oc new-app --template="${build_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=APP_NAME=$APP_NAME \
                       --param=NAMESPACE=$NAMESPACE \
                       --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                       --param=RHEL_VERSION=$RHEL_VERSION \
                       --param=NUM_CPUS=$NUM_DEVICES \
                       --param=CC=$GCC
        fi
    fi
else
    oc new-app --template=$build_job_name \
               --param=IMAGESTREAM_NAME=$IS_NAME \
               --param=REGISTRY=$OC_REGISTRY \
               --param=APP_NAME=$APP_NAME \
               --param=NAMESPACE=$NAMESPACE \
               --param=RHEL_VERSION=$RHEL_VERSION \
               --param=NUM_CPUS=$NUM_DEVICES \
               --param=CC=$GCC
fi

rm statuses.txt
