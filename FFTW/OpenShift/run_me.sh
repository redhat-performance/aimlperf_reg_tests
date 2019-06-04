#!/bin/bash

usage() {
    echo "This script launches the FFTW app on an AWS OpenShift cluster."
    echo ""
    echo "Usage: $0 [-v rhel_version] [-n] [-i instance_type]"
    echo "  REQUIRED:"
    echo "  -v  Version of RHEL to use. Choose from: {7,8}"
    echo ""
    echo "  OPTIONAL:"
    echo "  -n  Use NFD. (Requires option -i to be used!)"
    echo "  -i  Instance type (e.g., m4.4xlarge, m4.large, etc.)"
    exit
}

options=":h:v:i:n"
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
      i)
          INSTANCE_TYPE=${OPTARG}
          ;;
      *)
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Initialize vars
if [[ ${RHEL_VERSION} == 7 ]]; then
    IS_NAME="fftw-rhel7"
    APP_NAME="fftw-app-rhel7"
elif [[ ${RHEL_VERSION} == 8 ]]; then
    IS_NAME="fftw-rhel8"
    APP_NAME="fftw-app-rhel8"
else
    echo "Invalid version of RHEL. Choose from: {7,8}"
    exit 1
fi
OC_REGISTRY=$(oc registry info)
NAMESPACE=$(oc project | cut -d" " -f3 | cut -d'"' -f2)

echo $NFD

# Load templates
if [[ -z ${NFD} ]]; then
    build_image_template_name_prefix="fftw-build-image-rhel"
    build_image_template_filename_prefix="templates/standard/fftw-buildconfig-rhel"
    build_job_path="templates/standard/fftw-build-job.yaml"
    build_job_name="fftw-build-job"
else
    build_image_template_name_prefix="fftw-nfd-build-image-rhel"
    build_image_template_filename_prefix="templates/nfd/fftw-nfd-buildconfig-rhel"
    build_job_path="templates/nfd/fftw-nfd-build-job.yaml"
    build_job_name="fftw-nfd-build-job"
fi
if [[ ${RHEL_VERSION} == 7 ]]; then
    build_image_template_name="${build_image_template_name_prefix}7"
    build_image_template_file="${build_image_template_filename_prefix}7.yaml"
else
    build_image_template_name="${build_image_template_name_prefix}8"
    build_image_template_file="${build_image_template_filename_prefix}8.yaml"
fi
check_build_template=$(oc get templates ${build_image_template_name} | grep NAME)
if [[ ! -z $check_build_template ]]; then
    oc delete -f "${build_image_template_file}"
fi
oc create -f ${build_image_template_file}

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
    oc new-app --template="${build_image_template_name}" --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY --param=INSTANCE_TYPE=$INSTANCE_TYPE
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
    build_stopped_status=$(echo $oc_build_status | grep stopped)
done

if [[ ! -z $build_failed_status ]]; then
    echo "Image build FAILED, so build job will not run."
elif [[ ! -z $build_stopped_status ]]; then
    echo "Image build STOPPED, so build job will not run."
elif [[ "${NFD}" == "nfd" ]]; then
    oc new-app --template=$build_job_name --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY --param=APP_NAME=$APP_NAME --param=NAMESPACE=$NAMESPACE --param=USE_AVX=$INSTANCE_TYPE
else
    oc new-app --template=$build_job_name --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY --param=APP_NAME=$APP_NAME --param=NAMESPACE=$NAMESPACE
fi

rm statuses.txt
