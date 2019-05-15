#!/bin/bash

ANSIBLE_GIT_VERSION=$1
RELEASE=$(cat /etc/redhat-release)
RHEL_VERSION=

# Get RHEL version from kernel version
if [[ ${RELEASE} == *"7."* ]]; then
    RHEL_VERSION=7
elif [[ ${RELEASE} == *"8."* ]]; then
    RHEL_VERSION=8
else
    echo "ERROR. Unrecognized RHEL version. Exiting now."
    exit 1
fi

# If the version of RHEL is 7.x, then install EPEL to install python36. Also install git
if [[ ${RHEL_VERSION} == 7 ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum -y install git python36
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python36 get-pip.py
    rm get-pip.py

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
if [[ "${RHEL_VERSION}" == "7" ]]; then
    pip install -r requirements.txt
else
    pip3 install -r requirements.txt
fi

# Setup Ansible
if [[ "${RHEL_VERSION}" == "7" ]]; then
    python36 setup.py build
    python36 setup.py install
else
    python3.6 setup.py build
    python3.6 setup.py install
fi

# Clean up Ansible
cd ..
rm -rf ansible
