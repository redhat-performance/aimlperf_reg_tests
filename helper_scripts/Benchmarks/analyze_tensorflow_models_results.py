#!/usr/bin/python3

#################################################################################
# This script analyzes TensorFlow Models benchmark data. It gathers the average #
# number of samples, the average time, and the standard deviations for both.    #
#################################################################################
import sys
import os.path
import numpy as np

def parse_file(filename):
    """
    This function parses a log file to gather:
    (1.) Average number of samples
    (2.) Average performance time
    (3.) Standard deviation for both

    Inputs
    ======
    filename: string
      Name of the (log) file to parse

    Returns
    =======
    """

    # Check if the file is valid. This will throw an error and exit out of the script if it's not valid.
    check_file_validity(filename)

    # We will store results in this dict
    results_dict = {}

    # This will store the average examples per sec
    avg_examples_per_sec_list = []

    # Set vars
    epoch_number = -1
    previous_line_was_benchmark_results = False
    previous_line_was_step_timestamp_log = False
    previous_line_was_avg_examples_per_sec = False
    previous_line_was_batch_label = False
    previous_line_was_batch_index = False
    previous_line_was_timestamp_label = False
    previous_line_was_timestamp = False
    first_timestamp = -1
    last_timestamp = -1

    # Open the file
    with open(filename, "r") as log_file:
        for line in log_file:

            # If the line contains "Run benchmarks", then iterate through the benchmark results
            if "Run the benchmarks" in line:

                # Set this variable to 'True' so that we know we're ready to parse benchmark results
                previous_line_was_benchmark_results = True

            # If the previous line was a benchmark output, then do:
            elif previous_line_was_benchmark_results == True:
                
                # Split the line by " "
                benchmark_results = line.split()

                # Iterate through each item in the benchmark_results var
                for benchmark_data in benchmark_results:
                    
                    if "examples_per_sec" in benchmark_data:
                        previous_line_was_avg_examples_per_sec = True
                    
                    elif "timestamp" in benchmark_data:
                        previous_line_was_timestamp = True

                    elif previous_line_was_avg_examples_per_sec == True:
                        avg_examples_per_sec, _ = benchmark_data.split("}")
                        avg_examples_per_sec_list.append(float(avg_examples_per_sec))
                        previous_line_was_avg_examples_per_sec = False

                    elif previous_line_was_timestamp == True and "BatchTimestamp" not in benchmark_data:
                        try:
                            timestamp, _  = benchmark_data.split(">")
                            timestamp_as_float = float(timestamp)
                            if first_timestamp == -1:
                                first_timestamp = timestamp_as_float
                            elif last_timestamp < timestamp_as_float:
                                last_timestamp = timestamp_as_float
                        except ValueError:
                            continue
                        previous_line_was_timestamp = False

            # If the line starts with "Epoch", then we can grab the epoch number
            elif "Epoch" in line:
                break

                # Reset
                previous_line_was_benchmark_results = False

    # Get mean rate
    mean_rate = np.mean(avg_examples_per_sec_list)

    # Get standard deviation
    standard_dev_rate = np.std(avg_examples_per_sec_list)

    # Print avg example rate results
    print("Average examples per sec: %0.2f +/- %0.2f" % (mean_rate, standard_dev_rate))

    # Get total time
    total_time_hours = (last_timestamp - first_timestamp) / 60 / 60

    # Print total time
    print("Total time (hours): %0.2f" % (total_time_hours))
    print("  - Start timestamp: %0.2f" % (first_timestamp))
    print("  - End timestamp: %0.2f" % (last_timestamp))

def check_file_validity(filename):

    # Check the filename to see if it's a string
    if (not isinstance(filename, str)):
        raise TypeError("Filename '%s' is not a string." % filename)

    # Check if the file can be opened
    if (os.path.exists(filename) == False):
        raise IOError("Could not open filename '%s'. It does not exist." % filename)


def main():
    parse_file(sys.argv[1])

if __name__ == "__main__":
    main()
