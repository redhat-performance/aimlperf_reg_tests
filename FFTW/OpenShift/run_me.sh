#!/bin/bash

usage() {
    echo "This script launches the FFTW app on an AWS OpenShift cluster for RHEL 7 or RHEL 8. Node Feature Discovery may optionally be used for selecting specific nodes, and CPU Manager may optionally be used as well."
    echo ""
    echo ""
    echo "Usage: $0 [-v rhel_version] [-n] [-t instance_type] [-r image_registry] [-s namespace] [-i custom_imagestream_name] [-a custom_app_name] [-x instruction_set] [-p] [-c number_of_cpus] [-m memory_size]"
    echo "  REQUIRED:"
    echo "  -v  Version of RHEL to use. Choose from: {7,8}"
    echo ""
    echo ""
    echo "  OPTIONAL:"
    echo "  -n  Use NFD. (Requires option -i *or* -x to be used!)"
    echo "      -i  Custom ImageStream name (this is what your image will be named). Default: fftw-rhel<rhel-version>"
    echo "      -x  Use no-AVX, AVX, AVX2, or AVX512 instructions. Choose from: {no_avx, avx, avx2, avx512}. Currently cannot be combined with -i (this is a TODO)"
    echo ""
    echo "  -t  Instance type (e.g., m4.4xlarge, m4.large, etc.). Currently cannot be combined with AVX* instructions (this is a TODO)"
    echo ""
    echo "  -r  OpenShift Image Registry URL (e.g., image-registry.openshift-image-registry.svc:5000). If you do not use this flag, the registry defaults whatever \"oc registry info\" outputs."
    echo ""
    echo "  -s  Namespace to use."
    echo ""
    echo "  -a  Custom app name (this is what your app will be named). Default: fftw-app-rhel<rhel-version>"
    echo ""
    echo "  -p  Use CPU Manager. (Requires options -c and -m to be used!)"
    echo "      -c  Number of CPUs to use with CPU Manager (the -p option)"
    echo "      -m  Memory size to use with CPU Manager (the -p option)"
    echo ""
    echo "  -l  Thread values, as a comma-separated list, for running the benchmark."
    exit
}

options=":h:v:t:nr:s:i:a:x:c:pm:l:"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      v)
          RHEL_VERSION=${OPTARG}
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
      s)
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
      c)
          N_CPUS=${OPTARG}
          ;;
      m)
          MEMORY_SIZE=${OPTARG}
          ;;
      l)
          THREAD_VALUES=${OPTARG}
          ;;
      *)
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Check RHEL versioning
if [[ ${RHEL_VERSION} != 7 ]] && [[ ${RHEL_VERSION} != 8 ]]; then
    echo "Invalid version of RHEL. Choose from: {7,8}"
    exit 1
fi

# Check NFD options
if [[ ${NFD} == "nfd" ]] && [[ ! -z ${AVX} ]] && [[ -z ${INSTANCE_TYPE} ]]; then
    if [[ ${AVX} != "no_avx" ]] && [[ ${AVX} != "avx" ]] && [[ ${AVX} != "avx2" ]] && [[ ${AVX} != "avx512" ]]; then
        echo "Invalid value for -x. Choose from: {no_avx, avx, avx2, avx512}"
        exit 1
    fi
elif [[ ${NFD} == "nfd" ]] && [[ ! -z ${AVX} ]] && [[ ! -z ${INSTANCE_TYPE} ]]; then
    echo "Cannot request instance type and AVX* instructions at the same time. (This is a TODO feature that will be added in the future.)"
    exit 1
elif [[ ${NFD} == "nfd" ]] && [[ -z ${AVX} ]] && [[ -z ${INSTANCE_TYPE} ]]; then
    echo "Please specify either AVX instructions or instance type, but not both. (This is a TODO feature that will be added in the future.)"
    exit 1
fi

# Check CPU Manager options
if [[ ${CPU_MANAGER} ]]; then
    if [[ -z ${N_CPUS} ]]; then
        echo "ERROR. The CPU Manager option -p was passed, but the number of CPUs (-c) was not specified."
        exit 1
    elif [[ -z ${MEMORY_SIZE} ]]; then
        echo "ERROR. The CPU Manager option -p was passed, but the memory size (-m) was not specified."
        exit 1
    elif [[ ! ${N_CPUS} =~ ^[0-9]+$ ]]; then
        echo "ERROR. Number of CPUs is not a number. You entered: ${N_CPUS}"
        exit 1
    elif (( N_CPUS <= 0 )); then
        echo "ERROR. Number of CPUs must be a positive number. You entered: ${N_CPUS}"
        exit 1
    elif [[ ! ${MEMORY_SIZE} =~ ^[0-9]+G$ ]]; then
        echo "ERROR. Memory size must be in the format of <number>G. You entered: ${MEMORY_SIZE}"
        exit 1
    fi
fi

# Initialize image name (if not specified)
if [[ -z ${IS_NAME} ]]; then
    if [[ ${RHEL_VERSION} == 7 ]] && [[ ! -z ${AVX} ]]; then
        IS_NAME="fftw-rhel7-${AVX}"
    elif [[ ${RHEL_VERSION} == 7 ]] && [[ -z ${AVX} ]]; then
        IS_NAME="fftw-rhel7"
    elif [[ ${RHEL_VERSION} == 8 ]] && [[ ! -z ${AVX} ]]; then
        IS_NAME="fftw-rhel8-${AVX}"
    else
        IS_NAME="fftw-rhel8"
    fi
fi

# Initialize app name (if not specified)
if [[ -z ${APP_NAME} ]]; then
    if [[ ${RHEL_VERSION} == 7 ]]; then
        if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
            APP_NAME="fftw-app-rhel7-${AVX}-cpu-managed"
        elif [[ ! -z ${AVX} ]]; then
            APP_NAME="fftw-app-rhel7-${AVX}"
        else
            APP_NAME="fftw-app-rhel7"
        fi
    else
        if [[ ! -z ${CPU_MANAGER} ]] && [[ ! -z ${AVX} ]]; then
            APP_NAME="fftw-app-rhel8-${AVX}-cpu-managed"
        elif [[ ! -z ${AVX} ]]; then
            APP_NAME="fftw-app-rhel8-${AVX}"
        else
            APP_NAME="fftw-app-rhel8"
        fi
    fi
fi
if [[ -z ${OC_REGISTRY} ]]; then
    OC_REGISTRY=$(oc registry info)
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

# Load templates
if [[ -z ${NFD} ]]; then
    build_image_template_name_prefix="fftw-build-image-rhel"
    build_image_template_filename_prefix="templates/standard/fftw-buildconfig-rhel"
    build_job_path="templates/standard/fftw-build-job.yaml"
    build_job_name="fftw-build-job"
else

    # If the user passed in AVX instructions, then set the template variables to point to the proper AVX templates
    if [[ ! -z ${AVX} ]]; then
        build_image_template_name_prefix="fftw-nfd-${AVX}-build-image-rhel"
        build_image_template_filename_prefix="templates/nfd/instruction_sets/${AVX}/buildconfig/fftw-nfd-buildconfig-rhel"
        build_job_path_prefix="templates/nfd/instruction_sets/${AVX}/job"

        # If CPU Manager will be used, then specify the proper name
        if [[ ! -z ${CPU_MANAGER} ]]; then
            build_job_path="${build_job_path_prefix}/cpu_manager/fftw-nfd-build-job.yaml"
	    build_job_name="fftw-${AVX}-nfd-cpu-manager-build-job"
        else
            build_job_path="${build_job_path_prefix}/default/fftw-nfd-build-job.yaml"
	    build_job_name="fftw-${AVX}-nfd-build-job"
        fi
        
    # If the user passed in an instance type, then set the template variables to point to the instance type templates
    else
        build_image_template_name_prefix="fftw-nfd-build-image-rhel"
        build_image_template_filename_prefix="templates/nfd/instance/buildconfig/fftw-nfd-buildconfig-rhel"
        build_job_path_prefix="templates/nfd/instance/job"
	build_job_name="fftw-nfd-build-job"

        # If CPU Manager will be used, then specify the proper name
        if [[ ! -z ${CPU_MANAGER} ]]; then
            build_job_path="${build_job_path_prefix}/cpu_manager/fftw-nfd-build-job.yaml"
	    build_job_name="fftw-nfd-cpu-manager-build-job"
        else
            build_job_path="${build_job_path_prefix}/default/fftw-nfd-build-job.yaml"
	    build_job_name="fftw-nfd-build-job"
        fi
    fi
fi

# If the RHEL version is 7, then set the template name and file to point to the RHEL 7 ones
if [[ ${RHEL_VERSION} == 7 ]]; then
    build_image_template_name="${build_image_template_name_prefix}7"
    build_image_template_file="${build_image_template_filename_prefix}7.yaml"

# Otherwise, point to the RHEL 8 ones
else
    build_image_template_name="${build_image_template_name_prefix}8"
    build_image_template_file="${build_image_template_filename_prefix}8.yaml"
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
if [[ "${NFD}" == "nfd" ]]; then
    if [[ ! -z "${AVX}" ]]; then
        oc new-app --template="${build_image_template_name}" \
                   --param=IMAGESTREAM_NAME=$IS_NAME \
                   --param=REGISTRY=$OC_REGISTRY
    else
        oc new-app --template="${build_image_template_name}" \
                   --param=IMAGESTREAM_NAME=$IS_NAME \
                   --param=REGISTRY=$OC_REGISTRY \
                   --param=INSTANCE_TYPE=$INSTANCE_TYPE
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
echo "Checking build status..."
while [[ -z $build_succeeded_status ]] && [[ -z $build_failed_status ]] && [[ -z $build_stopped_status ]] && [[ -z $build_completed_status ]]; do
    sleep 10
    echo "Build is still running"
    oc status > statuses.txt 
    oc_build_status=$(grep -i -A 2 "bc/${build_image_template_name}" statuses.txt)
    build_succeeded_status=$(echo $oc_build_status | grep build | grep succeeded)
    build_completed_status=$(echo $oc_build_status | grep build | grep completed)
    build_failed_status=$(echo $oc_build_status | grep build | grep failed)
    build_stopped_status=$(echo $oc_build_status | grep build | grep stopped)
done

if [[ ! -z $build_failed_status ]]; then
    echo "Image build FAILED, so build job will not run."
elif [[ ! -z $build_stopped_status ]]; then
    echo "Image build STOPPED, so build job will not run."
elif [[ "${NFD}" == "nfd" ]]; then
    if [[ ! -z "${AVX}" ]]; then
        if [[ ! -z "${CPU_MANAGER}" ]]; then
            if [[ -z ${THREAD_VALUES} ]]; then
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE
            else
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE \
                           --param=THREAD_VALUES=$THREAD_VALUES
            fi
        else
            oc new-app --template="${build_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=APP_NAME=$APP_NAME \
                       --param=NAMESPACE=$NAMESPACE
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
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE
            else
                oc new-app --template="${build_job_name}" \
                           --param=IMAGESTREAM_NAME=$IS_NAME \
                           --param=REGISTRY=$OC_REGISTRY \
                           --param=APP_NAME=$APP_NAME \
                           --param=NAMESPACE=$NAMESPACE \
                           --param=INSTANCE_TYPE=$INSTANCE_TYPE \
                           --param=N_CPUS=$N_CPUS \
                           --param=MEMORY_SIZE=$MEMORY_SIZE \
                           --param=THREAD_VALUES=$THREAD_VALUES
            fi
        else
            oc new-app --template="${build_job_name}" \
                       --param=IMAGESTREAM_NAME=$IS_NAME \
                       --param=REGISTRY=$OC_REGISTRY \
                       --param=APP_NAME=$APP_NAME \
                       --param=NAMESPACE=$NAMESPACE \
                       --param=INSTANCE_TYPE=$INSTANCE_TYPE
        fi
    fi
else
    oc new-app --template=$build_job_name \
               --param=IMAGESTREAM_NAME=$IS_NAME \
               --param=REGISTRY=$OC_REGISTRY \
               --param=APP_NAME=$APP_NAME \
               --param=NAMESPACE=$NAMESPACE
fi

rm statuses.txt
