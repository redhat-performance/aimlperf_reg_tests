#!/bin/bash

# User inputs credentials file 
CREDENTIALS_FILE=$1

# User inputs config file
CONFIG_FILE=$2

# User also inputs profile name
PROFILE_NAME=$3

# Check if ${CREDENTIALS_FILE} exists
if [[ ! -f ${CREDENTIALS_FILE} ]]; then
    echo "ERROR. Could not find credentials file '${CREDENTIALS_FILE}'"
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

# Encode the access keys
encoded_access_key=$(echo -n ${aws_access_key} | base64)
encoded_secret_access_key=$(echo -n ${aws_secret_access_key} | base64)

# Replace the '[REPLACE ME]' strings with the encoded keys
credentials_secret_yaml="credentials_secret.yaml"
sed -i "s/  access_key:.*/  access_key: \"${encoded_access_key}\"/g" ${credentials_secret_yaml}
sed -i "s/  secret_access_key:.*/  secret_access_key: \"${encoded_secret_access_key}\"/g" ${credentials_secret_yaml}

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
	fi
    fi
done < "${CONFIG_FILE}"

# Encode the region and profile
encoded_aws_region=$(echo -n ${aws_region} | base64)
encoded_aws_profile=$(echo -n ${PROFILE_NAME} | base64)

# Replace the '[REPLACE ME]' strings with the encoded values
config_secret_yaml="config_secret.yaml"
sed -i "s/  region:.*/  region: \"${encoded_aws_region}\"/g" ${config_secret_yaml}
sed -i "s/  profile:.*/  profile: \"${encoded_aws_profile}\"/g" ${config_secret_yaml}
