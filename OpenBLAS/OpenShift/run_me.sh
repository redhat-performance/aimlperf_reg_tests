#!/bin/bash

RHEL_VERSION=$1

# Initialize vars
if [[ ${RHEL_VERSION} == 7 ]]; then
    IS_NAME="openblas-rhel7"
    APP_NAME="openblas-gemm-s2i-app-rhel7"
elif [[ ${RHEL_VERSION} == 8 ]]; then
    IS_NAME="openblas-rhel8"
    APP_NAME="openblas-gemm-s2i-app-rhel8"
else
    echo "Invalid version of RHEL. Choose from: {7,8}"
    exit 1
fi
OC_REGISTRY=$(oc registry info)
NAMESPACE=$(oc project | cut -d" " -f3 | cut -d'"' -f2)

# Load templates
if [[ ${RHEL_VERSION} == 7 ]]; then
    check_build_template=$(oc get templates openblas-gemm-rhel7 | grep NAME)
    if [[ ! -z $check_build_template ]]; then
        oc delete -f templates/openblas-buildconfig-rhel7.yaml
    fi
    oc create -f templates/openblas-buildconfig-rhel7.yaml
else
    check_build_template=$(oc get templates openblas-gemm-rhel8 | grep NAME)
    if [[ ! -z $check_build_template ]]; then
        oc delete -f templates/openblas-buildconfig-rhel8.yaml
    fi
    oc create -f templates/openblas-buildconfig-rhel8.yaml
fi
check_job_template=$(oc get templates openblas-gemm-build-job | grep NAME)
if [[ ! -z $check_job_template ]]; then
    oc delete -f templates/openblas-build-job.yaml
fi
oc create -f templates/openblas-build-job.yaml

# Check build configs
if [[ ${RHEL_VERSION} == 7 ]]; then
    check_bc=$(oc get bc openblas-gemm-app-rhel7 | grep NAME)
    if [[ ! -z $check_bc ]]; then
        oc delete bc openblas-gemm-app-rhel7
    fi
else
    check_bc=$(oc get bc openblas-gemm-app-rhel8 | grep NAME)
    if [[ ! -z $check_bc ]]; then
        oc delete bc openblas-gemm-app-rhel8
    fi
fi

# Check image streams
check_imagestream=$(oc get is $IS_NAME | grep NAME)
if [[ ! -z $check_imagestream ]]; then
    oc delete is $IS_NAME
fi

# Build the image
if [[ ${RHEL_VERSION} == 7 ]]; then
    check_existing_builds=$(oc get builds | grep openblas-gemm-app-rhel7)
    if [[ ! -z $check_existing_builds ]]; then
        oc delete build openblas-gemm-app-rhel7-1
    fi
    oc new-app --template=openblas-gemm-rhel7 --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY
    oc start-build openblas-gemm-app-rhel7
else
    check_existing_builds=$(oc get builds | grep openblas-gemm-app-rhel8)
    if [[ ! -z $check_existing_builds ]]; then
        oc delete build openblas-gemm-app-rhel8-1
    fi
    oc new-app --template=openblas-gemm-rhel8 --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY
    oc start-build openblas-gemm-app-rhel8
fi

# Build the app
check_existing_jobs=$(oc get jobs | grep $APP_NAME)
if [[ ! -z $check_existing_jobs ]]; then
    oc delete job $APP_NAME
fi

build_succeeded_status=""
build_failed_status=""
build_stopped_status=""
echo "Checking build status..."
while [[ -z $build_succeeded_status ]] && [[ -z $build_failed_status ]] && [[ -z $build_stopped_status ]]; do
    sleep 10
    echo "Build is still running"
    oc_build_status=$(oc status | grep build)
    build_succeeded_status=$(echo $oc_build_status | grep build | grep completed)
    build_failed_status=$(echo $oc_build_status | grep build | grep failed)
    build_stopped_status=$(echo $oc_build_status | grep stopped)
done

if [[ ! -z $build_failed_status ]]; then
    echo "Image build FAILED, so build job will not run."
elif [[ ! -z $build_stopped_status ]]; then
    echo "Image build STOPPED, so build job will not run."
else
    oc new-app --template=openblas-gemm-build-job --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY --param=APP_NAME=$APP_NAME --param=NAMESPACE=$NAMESPACE
fi
