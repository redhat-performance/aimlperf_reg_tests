#!/bin/bash

ANSIBLE_GIT_VERSION=$1
RELEASE=$(cat /etc/redhat-release | cut -d' ' -f 6)
RHEL_VERSION=

# Get RHEL version from kernel version
if [[ ${RELEASE} == "7."* ]]; then
    RHEL_VERSION=7
elif [[ ${RELEASE} == "8."* ]]; then
    RHEL_VERSION=8
else
    echo "ERROR. Unrecognized RHEL version '${RELEASE}'. Exiting now."
    exit 1
fi

# This script assumes Python has been installed for RHEL 7
python3_err_msg="ERROR. Python 3.6 is not installed. Please install Python 3.6 using ../Python/install_python_from_source.sh"
if [[ ${RHEL_VERSION} == 7 ]]; then

    # Check for the Python 3 executables
    if [[ -x /usr/bin/python3 ]] && [[ -x /usr/local/bin/python3 ]]; then
        echo ${python3_err_msg}
        exit 1
    else 
        python3_minor_version=$(python3 --version | cut -d' ' -f 2 | cut -d'.' -f 2)
        if (( python3_minor_version < 6 )); then
	    echo ${python3_err_msg}
	    exit 1
        fi
    fi

    yum -y install git

# Else, install python36 via dnf
else
    dnf -y install git python36
fi

# Get Ansible
git clone https://github.com/ansible/ansible.git

# Check out version of Ansible specified
cd ansible
git checkout tags/${ANSIBLE_GIT_VERSION}

# Install requirements via pip
pip3 install -r requirements.txt

# Set Python executable for RHEL 7
if [[ ${RHEL_VERSION} == 7 ]]; then
    sed -i "s/PYTHON=python/PYTHON=python3/g" Makefile && \
fi

# Setup Ansible
if [[ "${RHEL_VERSION}" == "7" ]]; then
    python3 setup.py build
    python3 setup.py install
else
    python3.6 setup.py build
    python3.6 setup.py install
fi

# Clean up Ansible
cd ..
rm -rf ansible
