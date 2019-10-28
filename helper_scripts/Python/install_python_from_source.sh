#!/bin/bash

# Specify Python version
PYTHON_VERSION=$1

# Get the Red Hat release so that we can figure out which version of RHEL we're using
release=$(cat /etc/redhat-release)
rhel_version=

# Get RHEL version from kernel version
if [[ ${release} == *"7."* ]]; then
    rhel_version=7
elif [[ ${release} == *"8."* ]]; then
    rhel_version=8
else
    echo "ERROR. Unrecognized RHEL version. Exiting now."
    exit 1
fi

# Install yum/dnf packages, depending on which version of RHEL is being used
if [[ ${rhel_version} == "7" ]]; then
    yum -y install gcc \
                   make \
                   openssl-devel \
                   wget \
                   zlib-devel

    rm -rf /var/cache/yum/*
else
    dnf -y install gcc \
	           make \
		   openssl-devel \
		   wget \
		   zlib-devel
    rm -rf /var/cache/dnf/*
fi

# Get Python 3.x.y
cd /tmp
wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz

# Untar the tarball
tar xvf Python-${PYTHON_VERSION}.tgz

# Configure Python 3.x.y
cd Python-${PYTHON_VERSION}
./configure --enable-optimizations

# Build Python
make

# Install Python
make install

# Remove tarball and build folder
rm -rf Python-${PYTHON_VERSION}
rm -rf Python-${PYTHON_VERSION}.tgz
