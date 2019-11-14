#!/bin/bash

# User inputs credentials file 
CREDENTIALS_FILE=$1

# User inputs config file
CONFIG_FILE=$2

# User also inputs profile name
PROFILE_NAME=$3

# Set CUDNN s3 bucket
CUDNN=$4

# Set NCCL s3 bucket
NCCL=$5

# Set TensorRT s3 bucket
TENSORRT=$6

# Check if ${CREDENTIALS_FILE} exists
if [[ ! -f ${CREDENTIALS_FILE} ]]; then
    echo "ERROR. Could not find credentials file '${CREDENTIALS_FILE}'"
    exit 1
fi

# Check if ${CONFIG_FILE} exists
if [[ ! -f ${CONFIG_FILE} ]]; then
    echo "ERROR. Could not find config file '${CONFIG_FILE}'"
    exit 1
fi

# Check if profile name is empty
if [[ -z ${PROFILE_NAME} ]]; then
    echo "ERROR. Profile name was not provided. Please provide a profile name."
    exit 1
fi

# Check CUDNN and NCCL (because TensorRT is optional)
if [[ -z ${CUDNN} ]]; then
    echo "ERROR. Missing value for cuDNN. Please provide an s3 bucket path to cuDNN."
    exit 1
elif [[ -z ${NCCL} ]]; then
    echo "ERROR. Missing value for NCCL. Please provide an s3 bucket path to NCCL."
    exit 1
fi

# Grab AWS access and secret access keys based on ${PROFILE_NAME}
found_profile=0
while IFS=" " read -r t || [ -n "${t}" ]; do
    if [[ "${t}" == "[${PROFILE_NAME}]" ]]; then
        found_profile=1
	continue
    fi
    if (( found_profile == 1 )); then
        if [[ "${t}" == "aws_access_key"* ]]; then
	    aws_access_key=$(echo ${t} | cut -d' ' -f 3)
        elif [[ "${t}" == "aws_secret_access_key"* ]]; then
            aws_secret_access_key=$(echo ${t} | cut -d' ' -f3)
	fi
    fi
done < "${CREDENTIALS_FILE}"

# Grab AWS config based on ${PROFILE_NAME}
found_profile=0
while IFS=" " read -r t || [ -n "${t}" ]; do
    if [[ "${t}" == *"${PROFILE_NAME}]" ]]; then
        found_profile=1
	continue
    fi
    if (( found_profile == 1 )); then
        if [[ "${t}" == "region"* ]]; then
	    aws_region=$(echo ${t} | cut -d' ' -f 3)
	    break
	fi
    fi
done < "${CONFIG_FILE}"

# Setup AWS environment vars file
aws_env_file="../aws_env.sh"
echo "export AWS_ACCESS_KEY=${aws_access_key}" > ${aws_env_file}
echo "export AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}" >> ${aws_env_file}
echo "export AWS_REGION=${aws_region}" >> ${aws_env_file}
echo "export AWS_PROFILE=${PROFILE_NAME}" >> ${aws_env_file}
echo "export CUDNN=${CUDNN}" >> ${aws_env_file}
echo "export NCCL=${NCCL}" >> ${aws_env_file}
echo "export TENSORRT=${TENSORRT}" >> ${aws_env_file}
