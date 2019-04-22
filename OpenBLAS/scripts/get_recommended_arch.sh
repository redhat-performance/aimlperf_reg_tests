#!/bin/bash

# This script gets the recommended target architecture for OpenBLAS

grep_arch_str=$(gcc -march=native -Q --help=target|grep march)
arch=$(echo $grep_arch_str | cut -d " " -f 2)

if [[ "$arch" == "haswell" || "$arch" == broadwell ]]; then
    echo "HASWELL"

elif [[ "$arch" == "ivybridge" || "$arch" == "sandybridge" ]]; then
    echo "SANDYBRIDGE"

elif [[ "$arch" == *"lake"* ]]; then
    echo "SKYLAKEX"

elif [[ "$arch" == "nehalem" || "$arch" == "westmere" ]] ; then
    echo "NEHALEM"

else
    echo "CORE2"
fi
