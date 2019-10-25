#!/bin/bash

usage() {
    echo "This script builds an ImageStream object for launching the TensorFlow CNN High-Performance benchmark app on an AWS OpenShift cluster for RHEL 7 only (for now). Node Feature Discovery may optionally be used for selecting specific nodes, and CPU Manager may optionally be used as well."
    echo ""
    echo ""
    echo "Usage: $0 [-v rhel_version] [-b backend] [-d number_of_devices] [-s secret_name] [-n] [-t instance_type] [-r image_registry] [-e namespace] [-i custom_imagestream_name] [-a custom_app_name] [-x instruction_set] [-p] [-c gcc_path] [-m memory_size] [-g]"
    echo "  REQUIRED:"
    echo "  -v  Version of RHEL to use. Choose from: {7, 8}."
    echo ""
    echo "  -b  NumPy backend to use with TensorFlow. Choose from: {fftw, openblas}" 
    echo ""
    echo "  -s  Pull secret name for pulling images from registry.redhat.io or the OpenShift Image Registry namespace. (You must have already created and loaded the secret into OpenShift.)"
    echo ""
    echo ""
    echo "  OPTIONAL:"
    echo "  -n  Use NFD. (Requires option -t *or* -x to be used!)"
    echo "      -t  Instance type (e.g., m4.4xlarge, m4.large, etc.). Currently cannot be combined with AVX* instructions (this is a TODO)"
    echo "      -x  Use no-AVX, AVX, AVX2, or AVX512 instructions. Choose from: {no_avx, avx, avx2, avx512}. Currently cannot be combined with -i (this is a TODO)"
    echo ""
    echo "  -i  Custom ImageStream name (this is what your image will be named). Default: fftw-rhel<rhel-version>"
    echo ""
    echo "  -r  OpenShift Image Registry URL (e.g., image-registry.openshift-image-registry.svc:5000). If you do not use this flag, the registry defaults whatever \"oc registry info\" outputs."
    echo ""
    echo "  -e  Namespace to use"
    echo ""
    echo "  -u  Use the GPU"
    exit
}

# Set default GPU usage
USE_GPU="false"

# Set vars
templates_path="templates"

options=":hv:b:s:nt:x:i:r:e:u"
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
      s)
          SECRET=${OPTARG}
          ;;
      n)
          NFD="nfd"
          ;;
      t)
          INSTANCE_TYPE=${OPTARG}
          ;;
      x)
          AVX=${OPTARG}
          ;;
      i)
          IS_NAME=${OPTARG}
          ;;
      r)
          OC_REGISTRY=${OPTARG}
          ;;
      e)
          NAMESPACE=${OPTARG}
          ;;
      u)
          USE_GPU="true"
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

# Check the instance type, if passed in
if [[ ! -z ${INSTANCE_TYPE} ]]; then

    instance_type_label="beta.kubernetes.io/instance-type=${INSTANCE_TYPE}"
    matching_nodes=$(oc describe node -l $instance_type_label)

    # If the instance type does not exist, throw an error
    if [[ -z ${matching_nodes} ]]; then
        echo "ERROR. No nodes found for instance type ${INSTANCE_TYPE}"
        exit 1
    fi
fi

# Initialize image name (if not specified)
if [[ -z ${IS_NAME} ]]; then

    if [[ ! -z ${AVX} ]]; then
        IS_NAME="tensorflow-${BACKEND}-rhel${RHEL_VERSION}-${AVX}"
    elif [[ ${USE_GPU} == "true" ]]; then
        IS_NAME="tensorflow-${BACKEND}-rhel${RHEL_VERSION}-gpu"
    else
        IS_NAME="tensorflow-${BACKEND}-rhel${RHEL_VERSION}"
    fi
fi

# Initialize app name (if not specified)
if [[ -z ${APP_NAME} ]]; then
    if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
        APP_NAME="tensorflow-s2i-benchmark-app-rhel${RHEL_VERSION}-${AVX}-cpu-managed"
    elif [[ ! -z ${AVX} ]]; then
        APP_NAME="tensorflow-s2i-benchmark-app-rhel${RHEL_VERSION}-${AVX}"
    elif [[ ${USE_GPU} == "true" ]]; then
        APP_NAME="tensorflow-s2i-benchmark-app-rhel${RHEL_VERSION}-gpu"
    else
        APP_NAME="tensorflow-s2i-benchmark-app-rhel${RHEL_VERSION}"
    fi
fi

# Set OpenShift registry
if [[ -z ${OC_REGISTRY} ]]; then 
     OC_REGISTRY="image-registry.openshift-image-registry.svc:5000"
fi

# Set namespace
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

# Check image streams
check_imagestream=$(oc get is $IS_NAME | grep NAME)
if [[ ! -z $check_imagestream ]]; then
    oc delete is $IS_NAME
fi

# Check the existing image builds
check_existing_builds=$(oc get builds | grep ${build_image_template_name})
if [[ ! -z $check_existing_builds ]]; then
    oc delete build "${build_image_template_name}-1"
fi

echo "------------------"
# Build the image
oc delete bc/${build_image_template_name}
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
echo "------------------"
echo "BUILD START"
echo "------------------"
oc start-build ${build_image_template_name}

# Check the image build
build_succeeded_status=""
build_completed_status=""
build_failed_status=""
build_stopped_status=""
build_pending_status=""
echo "Checking build status... (This may take up to 1 hour or more depending on the size and type of instance you're using.)"
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
fi

rm statuses.txt