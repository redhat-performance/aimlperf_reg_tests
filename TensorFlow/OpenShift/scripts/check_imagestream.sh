#!/bin/bash

RHEL_VERSION=$1
IS_NAME=$2
BACKEND=$3
BUILDCONFIG_NAME=$4
AVX=$5
USE_GPU=$6

# Get status of the build
found_bc_name="False"
build_num=-1
latest_build_status="null"
num_builds=0
oc status > statuses.txt
while IFS=" " read -r t || [ -n "$t" ]; do
    if [[ "$t" == "bc/${BUILDCONFIG_NAME}"* ]]; then
        found_bc_name="True"
	echo "HERE"
    elif [[ $found_bc_name == "True" ]]; then
        if [[ "$t" == *"build #"* ]]; then
            build_id=$(echo $t | cut -d' ' -f 2 | cut -d'#' -f 2)
            if (( build_id > build_num )); then
                build_num=$build_id
                latest_build_status=$(echo $t | cut -d' ' -f 3)
		num_builds=$((num_builds+1))
     	    fi
	fi
    fi
done < "statuses.txt"

echo ${BUILDCONFIG_NAME}
echo $num_builds
echo $latest_build_status

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
    latest_build_status=$(oc status | grep -A $((num_builds+1)) "bc/${BUILDCONFIG_NAME}")
    build_succeeded_status=$(echo $latest_build_status | grep succeeded)
    build_completed_status=$(echo $latest_build_status | grep completed)
    build_failed_status=$(echo $latest_build_status | grep failed)
    build_stopped_status=$(echo $latest_build_status | grep stopped)
    build_pending_status=$(echo $latest_build_status | grep pending)
    build_running_status=$(echo $latest_build_status | grep running)

    # Figure out when build is finally running
    if [[ ! -z ${build_running_status} ]] && [[ -z ${build_started} ]]; then
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
    if [[ ${build_running_status} ]]; then
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
	echo "[FATAL] - ${min_count}:${final_sec}] Image build STOPPED, so build job will not run. This happens when the previous build was interruped (e.g., CTRL+C or CTRL+Z was pressed, or a BuildConfig/ImageStream exists that shouldn't exist yet). If the image build is a Source-to-Image one (rather than a base image build), run 'make clean_s2i && make s2i' to restart the Source-to-Image process. Otherwise, run 'make clean && make' to restart the whole process."
else
    echo "[INFO] - ${min_count}:${final_sec}] Image '${IS_NAME}' was built successfully!"
fi

rm statuses.txt
