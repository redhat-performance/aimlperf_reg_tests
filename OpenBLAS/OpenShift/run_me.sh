#!/bin/bash

# Initialize vars
IS_NAME="openblas-rhel7"
OC_REGISTRY=$(oc registry info)
APP_NAME="openblas-gemm-s2i-app"
NAMESPACE=$(oc project | cut -d" " -f3 | cut -d'"' -f2)

# Load templates
check_build_template=$(oc get templates openblas-gemm | grep NAME)
if [[ ! -z $check_build_template ]]; then
    oc delete -f templates/openblas-buildconfig.yaml
fi
oc create -f templates/openblas-buildconfig.yaml
check_job_template=$(oc get templates openblas-gemm-build-job | grep NAME)
if [[ ! -z $check_job_template ]]; then
    oc delete -f templates/openblas-build-job.yaml
fi
oc create -f templates/openblas-build-job.yaml

# Check build configs
check_bc=$(oc get bc openblas-gemm-app | grep NAME)
if [[ ! -z $check_bc ]]; then
    oc delete bc openblas-gemm-app
fi

# Check image streams
check_imagestream=$(oc get is $IS_NAME | grep NAME)
if [[ ! -z $check_imagestream ]]; then
    oc delete is $IS_NAME
fi

# Build the image
check_existing_builds=$(oc get builds | grep openblas-gemm-app)
if [[ ! -z $check_existing_builds ]]; then
    oc delete build openblas-gemm-app-1
fi
oc new-app --template=openblas-gemm --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY
oc start-build openblas-gemm-app

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
    echo "Image build FAILED, so not build job will not run."
elif [[ ! -z $build_stopped_status ]]; then
    echo "Image build STOPPED, so not build job will not run."
else
    oc new-app --template=openblas-gemm-build-job --param=IMAGESTREAM_NAME=$IS_NAME --param=REGISTRY=$OC_REGISTRY --param=APP_NAME=$APP_NAME --param=NAMESPACE=$NAMESPACE
fi
