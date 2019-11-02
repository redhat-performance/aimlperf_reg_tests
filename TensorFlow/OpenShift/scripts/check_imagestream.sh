#!/bin/bash

RHEL_VERSION=$1
IS_NAME=$2
BACKEND=$3
AVX=$4
USE_GPU=$5

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

# Set the final second count
if (( sec_count == 0 )); then
    final_sec="00"
else
    final_sec="${sec_count}"
fi

# Prepare for debug statements
if [[ ! -z ${USE_GPU} ]]; then
    if [[ ${RHEL_VERSION} == "7" ]]; then
        cuda_version="10"
        dockerfile_suffix="_cuda10"
    else
        cuda_version="10.1"
        dockerfile_suffix="_cuda10.1"
    fi
elif [[ ${AVX} == "avx512" ]]; then
    dockerfile_suffix="_avx512"
fi
if [[ ${BACKEND} == "fftw" ]]; then
    dockerfile_folder="FFTW_backend"
else
    dockerfile_folder="OpenBLAS_backend"
fi

if [[ ! -z $build_failed_status ]]; then
    echo "[FATAL - ${min_count}:${final_sec}] Image build FAILED, so build job will not run."
    echo "[DEBUG - ${min_count}:${final_sec}] Possible solutions:"
    echo "[DEBUG - ${min_count}:${final_sec}]     >> Check if you've created an OpenShift Image Registry pull secret via a dockercfg. To create a dockercfg, run 'make -C setup/images openshift-secret' from the command line."
    echo "[DEBUG - ${min_count}:${final_sec}]     >> Check if you've forked this repository and modified your OpenShift image under ../Dockerfiles/${dockerfile_folder}/Dockerfile.openshift_rhel${RHEL_VERSION}${dockerfile_suffix}"
    echo "[DEBUG - ${min_count}:${final_sec}]     >> If you're using the GPU, check if you've modified and made a mistake in your base image (../Dockerfiles/custom/rhel${RHEL_VERSION}/cuda/Dockerfile.rhel${RHEL_VERSION}_cuda${cuda_version})."
elif [[ ! -z $build_stopped_status ]]; then
    echo "[FATAL] - ${min_count}:${final_sec}] Image build STOPPED, so build job will not run. This happens when the previous build was interruped (e.g., CTRL+C or CTRL+Z was pressed). Please rerun this script as it usually solves that error."
else
    echo "[INFO] - ${min_count}:${final_sec}] Image '${IS_NAME}' was built successfully! Please reference this image name when running 'launch_s2i_build.py'"
fi

rm statuses.txt
