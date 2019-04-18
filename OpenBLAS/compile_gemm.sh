#!/bin/bash

usage() {
    echo "Usage: $0 [-g gemm_type] [-I OpenBLAS_include_path] [-L OpenBLAS_lib_path] [-n OpenBLAS_lib_name] [-h]"
    echo "  REQUIRED:"
    echo "  -g  gemm type. Either \"sgemm\" or \"dgemm\"."
    echo "  -I  Path to OpenBLAS include files"
    echo "  -L  Path to OpenBLAS libs"
    echo "  -n  OpenBLAS lib itself. e.g., \"openblasp\""
    echo ""
    echo "  OPTIONAL:"
    echo "  -c  Path to cblas.h. By default, this is /path/to/openblas/include/cblas.h. Otherwise, you can use something such as /usr/include/openblas/cblas.h"
    exit
}

options=":hg:I:L:n:"
while getopts "$options" x
do
    case "$x" in
      h)  
          usage
          ;;
      g)
          gemm_type=${OPTARG}
          ;;
      I)
          openblas_include_path=${OPTARG}
          ;;
      L)  
          openblas_lib_path=${OPTARG}
          ;;
      n)  
          openblas_lib_name=${OPTARG}
          ;;
      c)
          cblas_path=${OPTARG}
          ;;
      *)  
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Do some error checking for user inputs
if [ -z "$gemm_type" ]; then
    echo "ERROR. Please pass in a gemm type. Either \"sgemm\" or \"dgemm\""
    exit 1
fi

if [[ -z "$openblas_include_path" ]]; then
    echo "ERROR. Please pass in an include path for OpenBLAS. e.g., /usr/include/openblas"
    exit 1
elif [[ ! -d "$openblas_include_path" ]]; then
    echo "ERROR. Invalid path $openblas_include_path. Path does not exist."
    exit 1
fi

if [[ -z "$openblas_lib_path" ]]; then
    echo "ERROR. Please pass in a path to the OpenBLAS libraries you want to use."
    exit 1
elif [[ ! -d "$openblas_lib_path" ]]; then
    echo "ERROR. Invalid path $openblas_include_path. Path does not exist."
    exit 1
fi

if [[ -z "$openblas_lib_name" ]]; then
    echo "ERROR. Please pass in the name of the threaded OpenBLAS lib. e.g., -lopenblasp"
    exit 1
fi

if [[ -z "$cblas_path" ]]; then
    cblas_path="$openblas_include_path/cblas.h"
fi

# Modify the location to cblas.h within the 

# Compile gemm_test.c based on user inputs
if [[ "$gemm_type" == "sgemm" ]]; then
    gcc -DSGEMM src/gemm_test.c -o sgemm_test -include$cblas_path -L$openblas_lib_path -I$openblas_include_path -l$openblas_lib_name -mcmodel=large
elif [[ "$gemm_type" == "dgemm" ]]; then
    gcc -DDGEMM src/gemm_test.c -o dgemm_test -include$cblas_path -L$openblas_lib_path -I$openblas_include_path -l$openblas_lib_name -mcmodel=large
else
    echo "ERROR. Invalid gemm type $gemm_type. Please choose from: \"sgemm\" or \"dgemm\""
    exit 1
fi
