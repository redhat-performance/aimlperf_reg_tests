#!/bin/bash

usage() {
    echo "Usage: $0 [-i iterations] [-e executable] [-j json_filename] [-r rank] [-d dimensions] [-f sampling_frequency] [-p] [-t] [-l log_filename] [-v thread_values] [-n] [-h]"
    echo "  REQUIRED:"
    echo "  -i  Number of iterations. For 2d_fft, use this value to emulate the number of images processed. For nd_cosine_ffts, use this value to emulate the number of cosine matrices to perform fourier transforms on."
    echo "  -e  Path to executable."
    echo "  -j  JSON document filename. Results of the FFTW benchmarks will be saved to a JSON document with this filename. Note that this file will NOT be overwritten. Instead, data will be appended to it."
    echo ""
    echo "  REQUIRED FOR nd_cosine_ffts"
    echo "  -r  Rank. The number of dimensions of the n-dimensional cosine"
    echo "  -d  Dimensions of the cosine matrix. Input as a list -- e.g., \"10 12 14\" -- and make sure the number of dimensions matches the rank"
    echo "  -f  Sampling frequency (fs). This value is a double."
    echo ""
    echo "  OPTIONAL FOR nd_cosine_ffts:"
    echo "  -p  Use this flag if you wish to plot the results of the cosine FFT program"
    echo ""
    echo "  OPTIONAL:"
    echo "  -t  Max number of threads to use. Omit this option if you want to use the max number of (real) cores on your system."
    echo "  -l  The resulting log of all the runs will be saved to a file with this name. (Default: fftw_runs.log)"
    echo "  -v  Values of the threads to use. For example, \"2 4 6 8\" will tell this script to run the tests on 2, 4, 6, and 8 threads."
    echo "  -n  Use numactl. This option is not required because Podman can't use numactl without running a privileged container."
    exit
}

# Set default values
run_log="fftw_runs.log"
max_threads=$(lscpu | awk '/^Core\(s\) per socket:/ {cores=$NF}; /^Socket\(s\):/ {sockets=$NF}; END{print cores*sockets}') #from https://stackoverflow.com/a/31646165
thread_values="-1"
use_numactl=0
executable="NULL"
num_executions=-2222
rank=-2222
fs=-2222
plot=0
json_doc="NULL"

options=":hpi:f:e:t:d:l:v:r:j:n"
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
      l)  
          run_log=${OPTARG}
          ;;
      v)  
          thread_values=${OPTARG}
          ;;
      n)
          use_numactl=1
          ;;
      r)
          rank=${OPTARG}
          ;;
      p)
          plot=1
          ;;
      d)
          dimensions=${OPTARG}
          ;;
      f)
          fs=${OPTARG}
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

# Make sure that the executable is recognizable by this script
if [ "$executable" != "2d_fft" ] && [ "$executable" != "nd_cosine_ffts" ]; then
    echo "This script does not recognize executable '$executable'. Please use either 2d_fft or nd_cosine_ffts."
    usage
fi

# Check if any of the benchmark executables exist
if [ ! -x $executable ]; then
    echo "The executable $executable does not exist! Please compile it by running `. ./compile_benchmark_code.sh /path/to/fftw/lib`"
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
#            FOR THE 2D_FFT EXECUTABLE            #
###################################################
if [ "$executable" == "2d_fft" ]; then

    # If no thread values were supplied, then iterate in powers of two
    if [ "$thread_values" == -1 ]; then
        echo "Using default thread values."
        for (( k=1; k<$max_threads; k*=2 ))
        do
            echo "Executing ./2d_fft $k $num_executions"
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((k-1)) -i 0,1 ./2d_fft $k $num_executions $json_doc >> $run_log
            else
                ./2d_fft $k $num_executions $json_doc >> $run_log
            fi
        done
        if [ $max_threads > $k ]; then
            echo "Executing ./2d_fft $max_threads $num_executions"
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((k-1)) -i 0,1 ./2d_fft $max_threads $num_executions $json_doc >> $run_log
            else
                ./2d_fft $k $num_executions $json_doc >> $run_log
            fi
        fi
    # Else, use the thread values the user specified
    else
        echo "Using custom thread values."
        for k in $thread_values; do
            echo "Executing ./2d_fft $k $num_executions"
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((k-1)) -i 0,1 ./2d_fft $k $num_executions $json_doc >> $run_log
            else
                ./2d_fft $k $num_executions $json_doc >> $run_log
            fi
        done
    fi

###################################################
#        FOR THE ND_COSINE_FFTS EXECUTABLE        #
###################################################
elif [ "$executable" == "nd_cosine_ffts" ]; then

    # Make sure the user input a rank. If not, throw an wrror
    if (( $rank == -2222)); then
        echo "Missing argument -r. Please supply a value for -r."
        usage
    elif (( $rank < 1 )); then
        echo "Rank is too low. Rank must be an integer between 1-99"
        exit
    elif (( $rank > 99 )); then
        echo "Rank is too high. Rank must be an integer between 1-99"
        exit
    fi

    # Make sure the user input a sampling frequency (Fs). If not, throw an error
    if (( $(echo "$fs == -2222" | bc -l) )); then
        echo "Missing argument -f. Please supply a value for -f."
        usage
    elif (( $(echo "$fs <= 0" | bc -l) )); then
        echo "Sampling frequency must be greater than 0."
        exit
    fi

    # Check the rank vs passed in dimensions
    export IFS=" "
    counter=0
    for value in $dimensions; do
        if (( $value < 0 )); then
            echo "Invalid value $value for dimension $counter"
            exit
        fi
        let counter=counter+1
    done
    if (( $counter < $rank )); then
        echo "The number of dimensions provided ($counter) does not match the rank ($rank)."
        exit
    fi

    # Determine if we should plot the results
    if [ $plot == 1 ]; then
        should_plot="plot"
    else
        should_plot="noplot"
    fi

    # If no thread values were supplied, then iterate in powers of two
    if [ "$thread_values" == -1 ]; then
        echo "Using default thread values."
        for (( k=1; k<$max_threads; k*=2 ))
        do
            echo "Executing ./nd_cosine_ffts $should_plot json=$json_doc nthreads=$k num_executions=$num_executions fs=$fs rank=$rank dims=\"$dimensions\""
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((k-1)) -i 0,1 ./nd_cosine_ffts $should_plot $json_doc $k $num_executions $fs $rank $dimensions >> $run_log
            else
                ./nd_cosine_ffts $should_plot $json_doc $k $num_executions $fs $rank $dimensions >> $run_log
            fi
        done
        if [ $max_threads > $k ]; then
            echo "Executing ./nd_cosine_ffts $should_plot json=$json_doc nthreads=$max_threads num_executions=$num_executions fs=$fs rank=$rank dims=\"$dimensions\""
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((max_threads-1)) -i 0,1 ./nd_cosine_ffts $should_plot $json_doc $max_threads $num_executions $fs $rank $dimensions >> $run_log
            else
                ./nd_cosine_ffts $should_plot $json_doc $max_threads $num_executions $fs $rank $dimensions >> $run_log
            fi
        fi
    # Else, use the thread values the user specified
    else
        echo "Using custom thread values."
        for k in ${thread_values//,/ }; do
            echo "Executing ./nd_cosine_ffts $should_plot json=$json_doc nthreads=$k num_executions=$num_executions fs=$fs rank=$rank dims=\"$dimensions\""
            if [ $use_numactl == 1 ]; then
                numactl -C 0-$((k-1)) -i 0,1 ./nd_cosine_ffts $should_plot $json_doc $k $num_executions $fs $rank $dimensions >> $run_log
            else
                ./nd_cosine_ffts $should_plot $json_doc $k $num_executions $fs $rank $dimensions >> $run_log
            fi
        done
    fi

else
    echo "Executable '$executable' exists but is not recognized by this script. Please use either 2d_fft or nd_cosine_ffts --> Exiting now."
    exit
fi
