#!/usr/bin/python3

#################################################################################
# This script analyzes TensorFlow Models benchmark data. It gathers the average #
# number of samples, the average time, and the standard deviations for both.    #
#################################################################################
import sys
import os.path
import numpy as np

FONT_SIZE=12
BATCH_SIZES=(64, 128, 256)

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
    batch_data
        Dictionary which contains train statistics for different batch sizes
    """

    # Check if the file is valid. This will throw an error and exit out of the script if it's not valid.
    check_file_validity(filename)

    # We will store results in this dict
    batch_data = {}

    # This will store the average examples per sec
    avg_examples_per_sec_list = []

    # This will store the global step (batch) sizes (that go along with the avg examples per sec)
    global_step_sizes = []

    # Set vars
    epoch_number = -1
    current_batch_size = -1
    previous_line_was_debug = False
    previous_line_was_step_timestamp_log = False
    previous_line_was_avg_examples_per_sec = False
    previous_line_was_batch_label = False
    previous_line_was_batch_index = False
    previous_line_was_timestamp_label = False
    previous_line_was_timestamp = False
    first_timestamp = -1
    last_timestamp = -1

    # Open the file
    with open(filename, 'r') as log_file:
        for line in log_file:

            # If the line contains "Run benchmarks", then iterate through the benchmark results
            if 'TASK [debug]' in line:

                # Set this variable to 'True' so that we know we're ready to parse benchmark results
                previous_line_was_debug = True

                # Set current batch size
                current_batch_size = -1

            # If the previous line was a benchmark output, then do:
            elif previous_line_was_debug == True:
                
                batch_size_is_valid = False
                for size in BATCH_SIZES:

                    if str(size) in line:
                        current_batch_size = size
                        batch_size_is_valid = True
                        break

                if batch_size_is_valid == False:
                    num_batch_sizes = len(BATCH_SIZES)
                    invalid_batch_size_error = 'Invalid batch size. Currently, the following batch sizes are supported: ['
                    for i, size in enumerate(BATCH_SIZES):
                        invalid_batch_size_error += str(size)

                        if i < (num_batch_sizes - 1):
                            invalid_batch_size_error += ', '
                        else:
                            invalud_batch_size_error += ']'
                    raise ValueError(invalid_batch_size_error)

                # Reset the variable to 'False' so that this statement can get triggered again
                previous_line_was_debug = False

            elif 'INFO:tensorflow:BenchmarkMetric:' in line and current_batch_size != -1 and 'epoch' not in line: 

                # Remove the 'INFO:tensorflow:BenchmarkMetric' part of the string
                _, benchmark_metric_data = line.split('{')

                # Split by comma so that we get something like ["'global step':100", "'time_taken': 29.077407", ... ]
                global_step_str, time_taken_str, examples_per_sec_str, _ = benchmark_metric_data.split(',')

                # Parse global step
                _, global_step_size = global_step_str.split(':')
                global_step_size = int(global_step_size)

                # Parse time taken
                _, time_taken = time_taken_str.split(':')
                time_taken = float(time_taken)

                # Parse examples per sec
                _, examples_per_sec = examples_per_sec_str.split(':')
                examples_per_sec, _ = examples_per_sec.split('}')
                examples_per_sec = float(examples_per_sec)

                # Now save results
                if batch_data == {}:
                    batch_data[current_batch_size] = [(global_step_size, time_taken, examples_per_sec)]
                elif current_batch_size not in batch_data:
                    batch_data[current_batch_size] = [(global_step_size, time_taken, examples_per_sec)]
                else:
                    existing_batch_data = batch_data[current_batch_size]
                    existing_batch_data.append((global_step_size, time_taken, examples_per_sec))
                    batch_data[current_batch_size] = existing_batch_data

            # Time to parse the timestamps
            elif 'BatchTimestamp' in line and current_batch_size != -1:

                # Get the first and last timestamp and store them in these vars:
                first_timestamp = -1
                last_timestamp = -1

                # Split the entries, which are separated by commas
                performance_data_entries = line.split(',')

                # Look for strings like 'BatchTimestamp<batch_index: 100, timestamp: 1574878094.6000183>'
                for entry in performance_data_entries:

                    if 'timestamp:' in entry:
                        _, timestamp_str = entry.split('timestamp:')
                        timestamp, _ = timestamp_str.split('>')
                        timestamp = float(timestamp)

                        if first_timestamp == -1:
                            first_timestamp = timestamp
                        elif last_timestamp < timestamp:
                            last_timestamp = timestamp

                total_duration = (last_timestamp - first_timestamp) / 60.0 / 60.0
                print('Total duration of benchmarks for batch size %d: %0.2f hours' % (current_batch_size, total_duration))

    return batch_data


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
    mins = []
    maxs = []
    medians = []
    batch_sizes_mins = []
    batch_sizes_maxs = []
    batch_sizes_medians = []
    all_yvals = []
    all_idxs = []

    # Each entry in the 'data' dict is an instance size. e.g., 'g3.4xlarge'
    for instance_type, instance_data in data.items():

        # Each entry in the 'instance_data' is a list of batch data
        for batch_size, batch_data in instance_data.items():

            # Grab all the y-values
            step_size, time_taken, yvals = zip(*batch_data)

            # Add to list
            all_yvals.extend(yvals)

            # Create idx list
            idx_list = [batch_size] * len(yvals)
            all_idxs.extend(idx_list)

        # Convert 'all_yvals' to numpy dict
        yvals = np.array(all_yvals)
    
        # Get median
        median_idx = np.argsort(yvals)[len(yvals)//2]
        median = yvals[median_idx]

        # Get median's corresponding batch size
        median_corresponding_batch_size = np.int(all_idxs[median_idx])

        # Get min
        min_idx = yvals.argmin()
        min_val = yvals[min_idx]
        min_corresponding_batch_size = np.int(all_idxs[min_idx])

        # Get max
        max_idx = yvals.argmax()
        max_val = yvals[max_idx]
        max_corresponding_batch_size = np.int(all_idxs[max_idx])

        # Remove the '.log' from the log file
        parsed_label, _ = instance_type.split('.log')

        # Save to lists
        labels_to_plot.append(parsed_label)
        data_to_plot.append(yvals)
        mins.append(min_val)
        maxs.append(max_val)
        medians.append(median)
        batch_sizes_mins.append(min_corresponding_batch_size)
        batch_sizes_maxs.append(max_corresponding_batch_size)
        batch_sizes_medians.append(median_corresponding_batch_size)

    # Begin plotting
    fig1, ax = plt.subplots()
    ax.set_title('Vanilla TensorFlow\'s ResNet56 Training Rates on Various AWS Instances\nusing the CIFAR-10 Dataset (60,000 Images)')
    ax.boxplot(data_to_plot)
    ax.set_xticklabels(labels_to_plot)
    plt.grid()

    # Get data to prepare text labels for the plot
    num_log_files_passed_in = len(data)
    start_x = (1.0 / (num_log_files_passed_in * 4.0)) + 1.1
    overall_max_val = -1
    med_val_at_max = -1
    for i in range(0,num_log_files_passed_in):

        # Unpack
        med = medians[i]
        max_val = maxs[i]
        med_batch_size = batch_sizes_medians[i]

        # Set the x- and y-locations for the text that displays the med value
        med_x_location, med_y_location = start_x, med

        # Keep track of the overall max value
        if max_val > overall_max_val:
            overall_max_val = max_val
            med_val_at_max = med

        # Increment
        start_x += 1

        # Plot text
        plt.text(med_x_location, med_y_location, 'median: %d (batch size = %d)' % (np.int(med), med_batch_size))

    # Now plot mins and maxs
    threshold = (overall_max_val / 50)
    start_x = (1.0 / (num_log_files_passed_in * 4.0)) + 1.1
    for i in range(0,num_log_files_passed_in):

        # Unpack
        max_val = maxs[i]
        min_val = mins[i]
        min_batch_size = batch_sizes_mins[i]
        max_batch_size = batch_sizes_maxs[i]

        # Set the x- and y-locations for the text that displays the max
        max_x_location, max_y_location = start_x, max_val

        # Set the x- and y-locations for the text that displays the min
        min_x_location, min_y_location = start_x, min_val

        # Check to make sure the labels don't overlap
        if (max_y_location - med_y_location) <= threshold:
            max_y_location +=  threshold

        plt.text(min_x_location, min_y_location, 'min: %d (batch size = %d)' % (np.int(min_val), min_batch_size))
        plt.text(max_x_location, max_y_location, 'max: %d (batch size = %d)' % (np.int(max_val), max_batch_size))

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
