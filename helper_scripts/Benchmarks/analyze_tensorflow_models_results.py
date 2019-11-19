#!/usr/bin/python3

#################################################################################
# This script analyzes TensorFlow Models benchmark data. It gathers the average #
# number of samples, the average time, and the standard deviations for both.    #
#################################################################################
import sys
import os.path
import numpy as np

FONT_SIZE=12

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
    results_dict
        Dictionary which contains train statistics and benchmark suite statistics 
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

    # Get total time
    total_time_hours = (last_timestamp - first_timestamp) / 60 / 60

    # Save to results dictionary
    results_dict = {'train_statistics':{
                                        'all_results': avg_examples_per_sec_list,
                                        'mean_rate': mean_rate, 'stdev_rate': standard_dev_rate
                                       },
                    'benchmark_suite_statistics':{
                                                  'total_time_hrs': total_time_hours
                                                 }
                   }

    return results_dict


def check_file_validity(filename):

    # Check the filename to see if it's a string
    if (not isinstance(filename, str)):
        raise TypeError("Filename '%s' is not a string." % filename)

    # Check if the file can be opened
    if (os.path.exists(filename) == False):
        raise IOError("Could not open filename '%s'. It does not exist." % filename)

def make_box_plot(data):
    """
    Makes a box plot out of 'data'

    Inputs
    ======
    data: dictionary
        Dictionary which contains lists of data points to make a box plot from

    Returns
    =======
    None
    """
    import matplotlib.pyplot as plt

    # Unpack the data
    data_to_plot = []
    labels_to_plot = []
    averages = []
    mins = []
    maxs = []
    for label, results_dict in data.items():

        # Grab all the y-values
        yvals = results_dict['train_statistics']['all_results']

        # Grab the average rate for the log file
        average = results_dict['train_statistics']['mean_rate']

        # Get min
        min_val = np.min(yvals)

        # Get max
        max_val = np.max(yvals)

        # Remove the '.log' from the log file
        parsed_label, _ = label.split('.log')

        # Save to lists
        labels_to_plot.append(parsed_label)
        data_to_plot.append(yvals)
        averages.append(average)
        mins.append(min_val)
        maxs.append(max_val)

    # Begin plotting
    fig1, ax = plt.subplots()
    ax.set_title('Vanilla TensorFlow\'s ResNet56 Training Rates on Various AWS Instances\nusing the CIFAR-10 Dataset (60,000 Images)')
    ax.boxplot(data_to_plot)
    ax.set_xticklabels(labels_to_plot)
    plt.grid()

    # Get data to prepare text labels for the plot
    num_log_files_passed_in = len(averages)
    start_x = (1.0 / (num_log_files_passed_in * 4.0)) + 1.1
    overall_max_val = -1
    avg_val_at_max = -1
    for i in range(0,num_log_files_passed_in):

        # Unpack
        avg = averages[i]
        max_val = maxs[i]

        # Set the x- and y-locations for the text that displays the avg value
        avg_x_location, avg_y_location = start_x, avg

        # Keep track of the overall max value
        if max_val > overall_max_val:
            overall_max_val = max_val
            avg_val_at_max = avg

        # Increment
        start_x += 1

        # Plot text
        plt.text(avg_x_location, avg_y_location, 'average: %d' % np.int(avg))

    # Now plot mins and maxs
    threshold = (overall_max_val / 50)
    start_x = (1.0 / (num_log_files_passed_in * 4.0)) + 1.1
    for i in range(0,num_log_files_passed_in):

        # Unpack
        avg = averages[i]
        max_val = maxs[i]
        min_val = mins[i]

        # Set the x- and y-locations for the text that displays the max
        max_x_location, max_y_location = start_x, max_val

        # Set the x- and y-locations for the text that displays the min
        min_x_location, min_y_location = start_x, min_val

        # Check to make sure the labels don't overlap
        if (max_y_location - avg_y_location) <= threshold:
            max_y_location +=  threshold

        plt.text(min_x_location, min_y_location, 'min: %d' % np.int(min_val))
        plt.text(max_x_location, max_y_location, 'max: %d' % np.int(max_val))

        start_x += 1

    plt.ylabel('Average # of Examples / sec', fontsize=FONT_SIZE)
    plt.xlabel('AWS Instance Type', fontsize=FONT_SIZE)

    plt.show()


def main():
    all_results = {}
    for i, arg in enumerate(sys.argv):
        if i == 0:
            continue
        results = parse_file(arg)
        all_results[arg] = results

    make_box_plot(all_results)

if __name__ == "__main__":
    main()
