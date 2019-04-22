#!/bin/bash

# This script looks for AVX instructions

# Get list of AVX flags (if they're turned on)
gcc_flags=$(lscpu | grep "Flags")
avx512_flags=$(echo $gcc_flags | grep "avx512")
avx2_flags=$(echo $gcc_flags | grep "avx2")
avx_flags=$(echo $gcc_flags | grep "avx")

AVX_FLAGS_STR=""

if [[ -z "$avx512_flags" ]]; then
    AVX_FLAGS_STR+="NO_AVX512=1 "
else
    AVX_FLAGS_STR+="NO_AVX512=0 "
fi

if [[ -z "$avx2_flags" ]]; then
    AVX_FLAGS_STR+="NO_AVX2=1 "
else
    AVX_FLAGS_STR+="NO_AVX2=0 "
fi

if [[ -z "$avx_flags" ]]; then
    AVX_FLAGS_STR+="NO_AVX=1"
else
    AVX_FLAGS_STR+="NO_AVX=0"
fi

echo $AVX_FLAGS_STR
