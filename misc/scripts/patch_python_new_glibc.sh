#!/bin/bash

# First argument is the path to the new glibc installation. (If using the glibc_installer playbook, this will be under
# /usr/local unless you specified a different install prefix via the 'install_prefix' extra var.)
NEW_GLIBC_PATH=$1

# Second argument is the path to python (e.g., /usr/bin/python or /usr/bin/python3, etc. etc.)
PYTHON_EXECUTABLE=$2

# Check if glibc path is empty
if [[ -z ${NEW_GLIBC_PATH} ]]; then
    echo "ERROR! No input was provided for NEW_GLIBC_PATH. Please provide an input."
    exit 1
fi

# Check if glibc path is a valid directory
if [[ ! -d ${NEW_GLIBC_PATH} ]]; then
    echo "ERROR! Could not access the following glibc path: ${NEW_GLIBC_PATH}"
    exit 1
fi

# Check if python executable is empty
if [[ -z ${PYTHON_EXECUTABLE} ]]; then
    echo "ERROR! No input was provided for PYTHON_EXECUTABLE."
    exit 1
fi

# Check if python executable is valid
if [[ ! -x ${PYTHON_EXECUTABLE} ]]; then
    echo "ERROR! ${PYTHON_EXECUTABLE} is not a valid executable."
    exit 1
fi

# Try to run a python command to see if the executable works
"${PYTHON_EXECUTABLE}" -c "from __future__ import print_function; print('Testing Python --> 2 + 2 =', 2 + 2)"

# Find ld-linux-x86-64.so.2 (or equivalent)
ld_linux_lib_name=$(ls "${NEW_GLIBC_PATH}"/lib | grep ld-linux*)

# If the ld-linux shared object library cannot be found, then look under a "lib64" folder
if [[ -z ${ld_linux_lib_name} ]];
    ld_linux_lib_name=$(ls "${NEW_GLIBC_PATH}"/lib64 | grep ld-linux*)

    if [[ -z ${ld_linux_lib_name} ]]; then
        echo "ERROR! Could not find the ld-linux shared object library under ${NEW_GLIBC_PATH}/lib or ${NEW_GLIBC_PATH}/lib64"
        exit 1
    fi
    "${NEW_GLIBC_PATH}/lib64/${ld_linux_lib_name}" --library-path "${NEW_GLIBC_PATH}"/lib "${PYTHON_EXECUTABLE}"
else
    "${NEW_GLIBC_PATH}/lib/${ld_linux_lib_name}" --library-path "${NEW_GLIBC_PATH}"/lib "${PYTHON_EXECUTABLE}"
fi

# Now try to run the python command again to confirm all is working as intended
"${PYTHON_EXECUTABLE}" -c "from __future__ import print_function; print('Testing Python --> 2 + 2 =', 2 + 2)"
