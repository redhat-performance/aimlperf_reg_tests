#!/bin/bash

usage() {
    echo "Usage: $0 [-i iterations] [-e executable] [-j json_filename] [-t] [-v thread_values] [-n] [-h]"
    echo "  REQUIRED:"
    echo "  -i  Number of iterations."
    echo "  -e  Path to executable (either 'dgemm_test' or 'sgemm_test')."
    echo "  -j  JSON document filename. Results of the OpenBLAS benchmarks will be saved to a JSON document with this filename. Note that this file will NOT be overwritten. Instead, data will be appended to it."
    echo ""
    echo "  OPTIONAL:"
    echo "  -t  Max number of threads to use. Omit this option if you want to use the max number of (real) cores on your system."
    echo "  -v  Values of the threads to use. For example, \"2 4 6 8\" will tell this script to run the tests on 2, 4, 6, and 8 threads."
    echo "  -n  Use numactl. This option is not required because Podman can't use numactl without running a privileged container."
    exit
}

# Set default values
max_threads=$(lscpu | awk '/^Core\(s\) per socket:/ {cores=$NF}; /^Socket\(s\):/ {sockets=$NF}; END{print cores*sockets}') #from https://stackoverflow.com/a/31646165
thread_values="-1"
use_numactl=0
executable="NULL"
num_executions=-2222
json_doc="NULL"

options=":hi:e:t:v:j:n"
while getopts "$options" x
do
    case "$x" in
      h)  
          usage
          ;;
      i)
          num_executions=${OPTARG}
          ;;
      e)
          executable=${OPTARG}
          ;;
      t)  
          max_threads=${OPTARG}
          ;;
      v)  
          thread_values=${OPTARG}
          ;;
      n)
          use_numactl=1
          ;;
      j)
          json_doc=${OPTARG}
          ;;
      *)  
          usage
          ;;
    esac
done
shift $((OPTIND-1))

###################################################
#         ERROR CHECKING FOR USER INPUTS          #
###################################################
# Check if an exectuable was passed in
if [ "$executable" == "NULL" ]; then
    echo "No executable was passed in. Please pass in an executable with the -e flag."
    usage
fi

# Check if any of the benchmark executables exist
if [ ! -x $executable ]; then
    echo "The executable $executable does not exist! Please compile it by running `. ./compile_gemm.sh -I<path/to/openblas/include> -L<path/to/openblas/lib> -n <openblas_lib_name> -g <gemm_type>`"
    exit
fi

# Check if the number of iterations was passed in
if (( $num_executions == -2222 )); then
    echo "Missing argument for number of iterations. Please pass in the number of iterations with the -i flag."
    usage
fi

# Check if JSON filename was passed
if [[ "$json_doc" == "NULL" ]]; then
    echo "No JSON document name was passed. Please supply a value for -j"
    usage
fi

###################################################
#            FOR THE GEMM EXECUTABLES             #
###################################################

if [ "$thread_values" == -1 ]; then
    echo "Using default thread values."
    for (( k=1; k<$max_threads; k*=2 ))
    do
        echo "executing ./$executable $k $num_executions $json_doc false"
        if [ $use_numactl == 1 ]; then
            numactl -c 0-$((k-1)) -i 0,1 ./$executable $k $num_executions $json_doc false
        else
            ./$executable $k $num_executions $json_doc false
        fi
    done
    if [ $k > $max_threads ]; then
        echo "executing ./$executable $max_threads $num_executions $json_doc false"
        if [ $use_numactl == 1 ]; then
            numactl -c 0-$((k-1)) -i 0,1 ./$executable $max_threads $num_executions $json_doc false
        else
            ./$executable $max_threads $num_executions $json_doc false
        fi
        rm -f $max_threads
    fi

else
    echo "Using custom thread values."
    for k in $thread_values; do
        echo "Executing ./$executable $k $num_executions $json_doc false"
        if [ $use_numactl == 1 ]; then
            numactl -C 0-$((k-1)) -i 0,1 ./$executable $k $num_executions $json_doc false
        else
            ./$executable $k $num_executions $json_doc false
        fi
    done
fi
