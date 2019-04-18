#define _DEFAULT_SOURCE
#define PI 3.141592653589793238462643383279
#define TIMELIMIT 2
#define BUFFSIZE 4096
#define PERFORMANCE_KEY "performance_results"
#define INPUTS_KEY "inputs"
#define RANK_KEY "rank"
#define DIMS_KEY "dims"
#define FS_KEY "fs_Hz"
#define ITERATIONS_KEY "iterations"
#define THREADS_KEY "threads"
#define FWD_DFT_RESULTS_KEY "forward_dft_results"
#define AVG_GFLOPS_KEY "average_gflops"
#define STDEV_GFLOPS_KEY "stdev_gflops"
#define BWD_DFT_RESULTS_KEY "backward_dft_results"
#define AVG_EXEC_TIME_SECONDS_KEY "average_execution_time_seconds"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <math.h>
#include <fftw3.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <regex.h>
#include <ctype.h>

void generate_cosine_data(double *cosine, double fs, int rank, int *n, int matrix_size);
void fill_row(double *cosine, double fs, int row_length, int start_idx, int n_sum, int matrix_size);
void plot1D(double *cosine, int dim, int rank, int *n, double fs, char *title);
int verifyCosineJSONFile(char *fftw_json_filename);

int main(int argc, char* argv[]){

    // Loop variables
    int i,j;

    // Parse inputs
    bool plot; //to plot or not to plot -- that is the question!
    char *plot_opt; //user passes either "plot" or "noplot" for plotting
    double fs; //sampling frequency (double values)
    int nthreads, niters, rank;
    char *filename;
    int n[100]; //will hold all of the rank data... max of 100 dims
    char *pEnd;
    if (argc == 1){
        fprintf(stderr, "No arguments were passed! Please enter: (1.) \"noplot\" or \"plot\" for plotting, (2.) JSON document name to save results to, (3.) number of threads to use, (4.) number of iterations to execute, (5.) the sampling frequency \"fs\" for the cosine, (6.) the rank of the cosine, and (7.) the size of each dimension.\n");
        exit(0);
    }
    else if (argc < 5){
        fprintf(stderr, "Only %d argument(s) given. Minimum number of arguments is 6. Please enter: (1.) \"noplot\" or \"plot\" for plotting, (2.) JSON document name to save results to, (3.) number of threads to use, (4.) number of iterations to execute, (5.) the sampling frequency \"fs\" for the cosine, (6.) the rank of the cosine, and (7.) the size of each dimension", argc-1);
        exit(0);
    }
    else{
        plot_opt = argv[1]; //set to "plot" to plot or "noplot" to not plot

        if (strcmp(plot_opt, "plot") == 0)
            plot=true;
        else if (strcmp(plot_opt, "noplot") == 0)
            plot=false;
        else{
            fprintf(stderr, "Invalid input '%s' for plotting. Please use \"plot\" or \"noplot\"\n", plot_opt);
            exit(0);
        }

        filename = argv[2];
        nthreads = (int)strtol(argv[3], &pEnd, 10);
        niters = (int)strtol(argv[4], &pEnd, 10);
        fs = atof(argv[5]);
        rank = (int)strtol(argv[6], &pEnd, 10);

        if (argc <= rank+6){
            fprintf(stderr, "Rank is set to %d, but %d dimensions were passed. The number of dimensions passed must equal the rank. Exiting now.\n", rank, (rank+6-argc));
            exit(0);
        }

        if (argc > rank+7){
            fprintf(stderr, "Rank is set to %d, but %d dimensions were passed. The number of dimensions passed must equal the rank. Exiting now.\n", rank, (argc-(rank+5)));
            exit(0);
        }

        for (i=7; i<rank+7; i++){
            n[i-7] = (int)strtol(argv[i], &pEnd, 10);
        }

        if (nthreads < 1){
            fprintf(stderr, "Number of threads must be greater than or equal to 1.\n");
            exit(0);
        }
        if (niters < 1){
            fprintf(stderr, "Number of iterations must be greater than or equal to 1.\n");
            exit(0);
        }
        if (fs <= 10e-9){
            fprintf(stderr, "Sampling frequency must be greater than 0.0. You entered: %0.2e\n", fs);
            exit(0);
        }
        if (rank < 1){
            fprintf(stderr, "The rank must be greater than or equal to 1.\n");
            exit(0);
        }
    }

    // If the file exists, let's check that it's valid
    if (access(filename, F_OK) != -1){
        printf("Validating existing JSON file '%s'\n", filename);
        int valid = verifyCosineJSONFile(filename);
        if (valid != 0)
            exit(0);
    }

    // Cosine variables
    int n_total = 1;

    // Plot variables
    char *title = "Resulting cosine Curve After Forward and Backward DFTs";

    // FFTW variables
    unsigned flags = FFTW_ESTIMATE;

    // Performance variables
    struct timeval forward_dft_start, forward_dft_stop;
    struct timeval backward_dft_start, backward_dft_stop;
    double forward_dft_execution_time_us = 0.0; //Forward DFT execution time in microseconds (us)
    double backward_dft_execution_time_us = 0.0; //Backward DFT in us
    double total_f_dft_exec_time_us = 0.0; //total forward DFT in us
    double total_b_dft_exec_time_us = 0.0; //total backward DFT in us

    // Get the total number of indices
    for (i=0; i<rank; i++){
        n_total *= n[i];
    }

    // For a complex transform, we have n[0] x n[1] x n[2] x ... x (n[rank-1]/2 + 1). So, our math is
    // as follows: n_total = n[0] x n[1] x n[2] x ... x n[rank-1]. Since n_total includes n[d-1], we have
    // to divide n_total by n[rank-1] to get n_toral = n[0] x n[1] x n[2] x ... x n[rank-2]. Then we 
    // multiply by n[rank-1] / 2 + 1
    int n_complex_total = (n_total / n[rank-1]) * (n[rank-1] / 2 + 1);

    // Set threading
    fftw_init_threads();
    fftw_plan_with_nthreads(nthreads);

    // Allocate memory for cosine data
    double *cosine = (double*)malloc(n_total * sizeof(double));

    // Fill N-dimensional cosine matrix
    generate_cosine_data(cosine, fs, rank, n, n_total);

    // Set time limit so that FFTW doesn't spend too much time trying to figure out the "best" algorithm.
    fftw_set_timelimit(TIMELIMIT);

    // Initialize real-to-complex cosine input and output
    double *cosine_original = (double*)fftw_malloc(n_total * sizeof(double));
    fftw_complex *cosine_complex = (fftw_complex*)fftw_malloc(n_complex_total * sizeof(fftw_complex));

    // Initialize the cosine that will be returned from the complex DFT
    double *cosine_back = (double*)fftw_malloc(n_total * sizeof(double));

    // We'll need to do work on a dummy array to prevent the compiler from optimizing the loop
    int dummy[niters];
    srand(time(0));
    int rand_idx; //random index
    int max_idx = n_total - 1; //max index of the cosine array (matrix)
    double *fft_performance_times_us = malloc(niters * sizeof(double));
    double *ifft_performance_times_us = malloc(niters * sizeof(double));

    // Iterate
    for (j=0; j<niters; j++){
        // Create FFTW plans
        fftw_plan forward_cos_dft_plan = fftw_plan_dft_r2c(rank, n, cosine_original, cosine_complex, flags);
        fftw_plan backward_cos_dft_plan = fftw_plan_dft_c2r(rank, n, cosine_complex, cosine_back, flags);

        // Fill input cosine array (this MUST be done after the fftw plans are created)
        for (i=0; i<n_total; i++)
            cosine_original[i] = cosine[i];

        // Execute Forward DFT and capture performance time
        gettimeofday(&forward_dft_start, NULL); //start clock
        fftw_execute(forward_cos_dft_plan);
        gettimeofday(&forward_dft_stop, NULL); //stop clock
        forward_dft_execution_time_us = (forward_dft_stop.tv_sec - forward_dft_start.tv_sec) * (1e6); //sec to us
        forward_dft_execution_time_us += (forward_dft_stop.tv_usec - forward_dft_start.tv_usec);
        total_f_dft_exec_time_us += forward_dft_execution_time_us;
        fft_performance_times_us[j] = forward_dft_execution_time_us;

        // Execute Backward DFT and capture performance time
        gettimeofday(&backward_dft_start, NULL); //start clock
        fftw_execute(backward_cos_dft_plan);
        gettimeofday(&backward_dft_stop, NULL); //stop clock
        backward_dft_execution_time_us = (backward_dft_stop.tv_sec - backward_dft_start.tv_sec) * (1e6);// sec to us
        backward_dft_execution_time_us += (backward_dft_stop.tv_usec - backward_dft_start.tv_usec);
        total_b_dft_exec_time_us += backward_dft_execution_time_us;
        ifft_performance_times_us[j] = backward_dft_execution_time_us;

        // Do work on dummy array to prevent the compiler from optimizing on its own
        rand_idx = rand() % (max_idx + 1);
        dummy[j] = j + cosine_back[rand_idx];

        // Destroy FFTW plans
        fftw_destroy_plan(forward_cos_dft_plan);
        fftw_destroy_plan(backward_cos_dft_plan);
    }

    // Free memory
    fftw_free(cosine_original);
    fftw_free(cosine_complex);

    // Handle threading
    fftw_cleanup_threads();

    // Get average times
    double average_forward_dft_exec_time_us = total_f_dft_exec_time_us / niters;
    double average_backward_dft_exec_time_us = total_b_dft_exec_time_us / niters;

    // Compute teraflops (see here for info on how to calculate mflops: http://www.fftw.org/speed/)
    long double forward_dft_mflops_approx = 5 * n_total * log2l(n_total) / (average_forward_dft_exec_time_us * 2);
    long double backward_dft_mflops_approx = 5 * n_total * log2l(n_total) / (average_backward_dft_exec_time_us * 2);

    long double forward_dft_gflops_approx = forward_dft_mflops_approx * (1e-3);
    long double backward_dft_gflops_approx = backward_dft_mflops_approx * (1e-3);

    // Compute standard dev
    double forward_dft_diff_us, backward_dft_diff_us;
    double forward_dft_squared_diff, backward_dft_squared_diff;
    double forward_dft_squared_diff_totals = 0;
    double backward_dft_squared_diff_totals = 0;

    // Step 1: Get mean (which we already did)
    for (i=0; i<niters; i++){

        // Step 2: For each number, subtract the mean
        forward_dft_diff_us = fft_performance_times_us[i] - average_forward_dft_exec_time_us;
        backward_dft_diff_us = ifft_performance_times_us[i] - average_backward_dft_exec_time_us;

        // Step 3: Square the results
        forward_dft_squared_diff = forward_dft_diff_us * forward_dft_diff_us;
        backward_dft_squared_diff = backward_dft_diff_us * backward_dft_diff_us;

        // Step 4: Save squared differences to ge the mean.
        forward_dft_squared_diff_totals += forward_dft_squared_diff;
        backward_dft_squared_diff_totals += backward_dft_squared_diff;
    }

    // Compute standard deviation in seconds
    long double forward_dft_stdev_us = pow((forward_dft_squared_diff_totals / niters), 0.5);
    long double backward_dft_stdev_us = pow((backward_dft_squared_diff_totals / niters), 0.5);

    // Compute standard deviation as a percentage
    long double forward_dft_stdev_percentage = forward_dft_stdev_us / total_f_dft_exec_time_us;
    long double backward_dft_stdev_percentage = backward_dft_stdev_us / total_b_dft_exec_time_us;

    // Compute standard deviation in terms of GFlops
    long double forward_dft_stdev_gflops = forward_dft_gflops_approx * forward_dft_stdev_percentage;
    long double backward_dft_stdev_gflops = backward_dft_gflops_approx * backward_dft_stdev_percentage;

    // Fix cosine_back because its height has been adjusted by the FFT
    for (i=0; i<n_total; i++)
        cosine_back[i] /= n_total;

    // Plot result to ensure we get back what we put in!
    if (plot == true)
        plot1D(cosine_back, 1, rank, n, fs, title);

    //Now put 'dummy' to use so that the compiler doesn't get rid of it
    cosine_back[0] = dummy[0];

    // Prepare file to save results to
    char *tmp_filename = "tmp.json";

    // Open the temporary file for writing
    FILE *tmp_file = fopen(tmp_filename, "w");

    // If there's an existing file, we'll need to open it, read it, copy the lines, then add to a new file
    bool file_exists = false;
    if (access(filename, F_OK) != -1){

        // Change file_exists to 'true' because the file exists!
        file_exists = true;

        // Iterate through all the lines to get the length of the file
        char buffer[BUFFSIZE] = {'\0'};

        // Results file
        FILE *results_file = fopen(filename, "r");

        // We want to copy every single line into a temporary file EXCEPT the last line, hence "current_line_no < file_length"
        char curr_char = '\0';
        while (fgets(buffer, BUFFSIZE, results_file)){

            // The second to last line in the file will end with "    }", so if we see this case, then we stop the loop.
            if (buffer[0] == ' ' && buffer[1] == ' ' && buffer[2] == ' ' && buffer[3] == ' ' && buffer[4] == '}' && buffer[5] != ',')
                break;

            // Iterate through all the characters in 'buffer'
            for (i=0; i<BUFFSIZE; i++){

                // Get current character
                curr_char = buffer[i];

                // If the last character is not "\n", then it means we still have characters that we need to write to the file
                if (curr_char != '\0')
                    fputc(curr_char, tmp_file);

                // Clear buffer
                buffer[i] = '\0';
            }
        }

        // Finally,
        fprintf(tmp_file, "    },\n");
    }

    // Get timestamp
    time_t raw_time = time(NULL);
    struct tm *timeinfo;
    timeinfo = localtime(&raw_time);

    // Save as JSON
    if (file_exists == false)
        fprintf(tmp_file, "{\n");
    else
        fprintf(tmp_file, "\n");
    fprintf(tmp_file, "    \"%d-%d-%d %d:%d:%d\": {\n", timeinfo->tm_year+1900, timeinfo->tm_mon+1, timeinfo->tm_mday, timeinfo->tm_hour, timeinfo->tm_min, timeinfo->tm_sec);
    fprintf(tmp_file, "        \"performance_results\": {\n");
    fprintf(tmp_file, "            \"inputs\": {\n");
    fprintf(tmp_file, "                \"rank\": %d,\n", rank);
    fprintf(tmp_file, "                \"dims\": [");
    for (i=0; i<rank-1; i++){
        fprintf(tmp_file, " %d,", n[i]);
    }
    fprintf(tmp_file, " %d],\n", n[rank-1]);
    fprintf(tmp_file, "                \"fs_Hz\": %0.2e,\n", fs);
    fprintf(tmp_file, "                \"iterations\": %d,\n", niters);
    fprintf(tmp_file, "                \"threads\": %d\n", nthreads);
    fprintf(tmp_file, "            },\n");
    fprintf(tmp_file, "            \"forward_dft_results\": {\n");
    fprintf(tmp_file, "                \"average_execution_time_seconds\": %0.5f,\n", average_forward_dft_exec_time_us * (1e-6));
    fprintf(tmp_file, "                \"average_gflops\": %0.5Lf,\n", forward_dft_gflops_approx);
    fprintf(tmp_file, "                \"stdev_gflops\": %0.5Lf\n", forward_dft_stdev_gflops);
    fprintf(tmp_file, "            },\n");
    fprintf(tmp_file, "            \"backward_dft_results\": {\n");
    fprintf(tmp_file, "                \"average_execution_time_seconds\": %0.5f,\n", average_backward_dft_exec_time_us * (1e-6));
    fprintf(tmp_file, "                \"average_gflops\": %0.5Lf,\n", backward_dft_gflops_approx);
    fprintf(tmp_file, "                \"stdev_gflops\": %0.5Lf\n", backward_dft_stdev_gflops);
    fprintf(tmp_file, "            }\n");
    fprintf(tmp_file, "        }\n");
    fprintf(tmp_file, "    }\n");
    fprintf(tmp_file, "}\n");

    // Make sure to close file!
    fclose(tmp_file);

    // Change filename now
    rename(tmp_filename, filename);

    printf("\nPERFORMANCE RESULTS\n");
    printf("===================\n");
    printf("Input Info:\n");
    printf("    One %dD cosine: %d", rank, n[0]);
    for (i=1; i<rank; i++)
        printf(" x %d", n[i]);
    printf(" samples\n");
    printf("    fs = %0.2e Hz\n", fs);
    printf("    %d iterations\n", niters);
    printf("    %d threads used\n", nthreads);
    printf("DFT Results\n");
    printf("    Forward DFT execution time: %0.3f sec\n", average_forward_dft_exec_time_us * (1e-6));
    printf("    Forward DFT GFlops: %0.3Lf\n", forward_dft_gflops_approx);
    printf("    Backward DFT execution time: %0.3f sec\n", average_backward_dft_exec_time_us * (1e-6));
    printf("    Backward DFT GFlops: %0.3Lf\n", backward_dft_gflops_approx);

    return 0;
}

void fill_row(double *cosine, double fs, int row_length, int start_idx, int n_sum, int matrix_size){
/* Helper function to fill a row of data in an N-dimensional cosine matrix
 *
 * Inputs
 * ======
 *   double *cosine
 *       The array to be filled with cosine data
 *
 *   int fs
 *       Sample size for the cosine
 *
 *   int row_length
 *       Length of the dimension (AKA the length of the row to fill)
 *
 *   int start_idx
 *       Index of the cosine array to start filling
 *
 *   int n_sum
 *       Sum of all the values in n
 *
 *   int matrix_size
 *       Total number of samples in the "cosine" matrix across all dimensions (i.e., n0*n1*n2*...*nK)
 */
    if (start_idx < matrix_size){
        int i; //iterative var
        for (i=0; i<row_length; i++){
            cosine[i+start_idx] = cos((i+start_idx)*fs*PI);
        }

        fill_row(cosine, fs, row_length, start_idx+n_sum, n_sum, matrix_size);
    }
}

void generate_cosine_data(double *cosine, double fs, int rank, int *n, int matrix_size){
/* Generates data for a forward FFT
 *
 * Inputs
 * ======
 *   double *cosine
 *       The array to be filled with cosine data
 *
 *   int fs
 *       Sample size for the cosine
 *
 *   int rank
 *       Number of dimensions in the data array
 *
 *   int *n
 *       An array which contains the dimensions of the data array
 *
 *   int matrix_size
 *       Total number of samples in the "cosine" matrix across all dimensions (i.e., n0*n1*n2*...*nK)
 */

    // Init values
    int i; //iterative value
    int start = 0; //start of the next dimension
    int prev = 0; //start of the previous dimension
    int dim; //current dimension
    int n_sum = 0; //sum of all the dimensions

    // Get the sum of all N values. This will help us with indexing the cosine matrix when we go to
    // fill it with data
    for (i=0; i<rank; i++){
        n_sum += n[i];
    }

    // Fill cosine array
    for (i=0; i<rank; i++){

        // Get current dimension
        dim = n[i];

        // Get starting point
        start += prev;

        // Fill array
        fill_row(cosine, fs, dim, start, n_sum, matrix_size);

        // Update 'prev'
        prev = dim;
    }
}

void plot1D(double *cosine, int dim_to_plot, int rank, int *n, double fs, char *title){
/* Plot cosine data for a specific dimension
 *
 * Inputs
 * ======
 *   double *cosine
 *       The array to be filled with cosine data
 *
 *   int dim_to_plot
 *       Dimension of the nD cosine to plot
 *
 *   int rank
 *       Number of dimensions in the data array
 *
 *   int *n
 *       An array which contains the dimensions of the data array
 *
 *   double fs
 *       Sampling frequency
 *
 *   char *title
 *       Title of the plot
 */
    // Get the length of the dimension
    int N = n[dim_to_plot];

    // Init values
    int i; //iterative value
    int n_sum = 0; //sum of all the values in n
    int row_start_idx = 0; //Start and end of the row for the given dimension
    double *xvals = (double*)malloc(N * sizeof(double)); //allocate memory for x values
    double *yvals = (double*)malloc(N * sizeof(double)); //allocate memory for y values

    // Get the starting point and the sum of all values in n
    for (i=1; i<rank-1; i++){
        n_sum += n[i];

        if (dim_to_plot <= rank)
            row_start_idx += n[i-1];
    }

    // Now gather data and store in x- and y-value arrays
    for (i=0; i<N; i++){

        // Get x-values (simply just store index i)
        xvals[i] = i * fs * PI;

        // Get y-values
        yvals[i] = cosine[i+row_start_idx];
        row_start_idx += n_sum;
    }

    // File to save data in
    FILE *cosine_data_file = fopen("cosine_data.txt", "w");
    for (i=0; i<N; i++){
        fprintf(cosine_data_file, "%lf %lf \n", xvals[i], yvals[i]);
    }

    // Open gnuplot
    FILE *gnuplot_pipe = popen("gnuplot -persistent", "w");

    // Prepare title (no more than 100 chars)
    char plot_title[100];
    sprintf(plot_title, "set title \"%s\" offset 0,200", title);

    // Prepare gnuplot commands
    char *gnuplot_cmds[] = {plot_title, "set lmargin screen 0.10", "set bmargin screen 0.05", "set rmargin screen 0.95", "set tmargin screen 0.95", "set grid ytics lc rgb \"#bbbbbb\" lw 1 lt 0", "set grid xtics lc rgb \"#bbbbbb\" lw 1 lt 0", "set ylabel \"IFFT ( DFT ( cos(x) ) )\" offset -200", "set xtics pi offset 0,-200", "set format x '%.0Pπ'", "plot 'cosine_data.txt' with line notitle"};

    // Now plot
    for (i=0; i<11; i++){
        fprintf(gnuplot_pipe, "%s \n", gnuplot_cmds[i]);
    }
}

int verifyCosineJSONFile(char *fftw_json_filename){
    /* This function verifies that a JSON file is valid and in the proper format for the input to
     * an FFTW executable.
     *
     * Inputs
     * ------
     * char *fftw_json_filename
     *     File to verify
     *
     * Error codes
     * -----------
     *  -1 : Invalid filename
     *  -2 : Invalid key found in JSON file
     *  -3 : Invalid number of brackets or curly braces
     *  -4 : Invalid line (e.g., we have extra chars that are not null, ' ', or a bracket
     *  -5 : Too many commas or periods
     *  -6 : Invalid format for Fs (should be in the format of w.xe+yz or w.xe-yz)
     */

    // Check if file exists. If not, throw an error and return error code -1
    if (access(fftw_json_filename, F_OK) == -1){
        fprintf(stderr, "Invalid filename '%s'.\n", fftw_json_filename);
        return -1;
    }

    // Open file
    FILE *fftw_json_file = fopen(fftw_json_filename, "r");

    // Get key lengths
    const int performance_key_len = strlen(PERFORMANCE_KEY);
    const int input_key_len = strlen(INPUTS_KEY);
    const int rank_key_len = strlen(RANK_KEY);
    const int dims_key_len = strlen(DIMS_KEY);
    const int fs_key_len = strlen(FS_KEY);
    const int iterations_key_len = strlen(ITERATIONS_KEY);
    const int threads_key_len = strlen(THREADS_KEY);
    const int fwd_dft_results_key_len = strlen(FWD_DFT_RESULTS_KEY);
    const int avg_gflops_key_len = strlen(AVG_GFLOPS_KEY);
    const int stdev_gflops_key_len = strlen(STDEV_GFLOPS_KEY);
    const int bwd_dft_results_key_len = strlen(BWD_DFT_RESULTS_KEY);
    const int avg_exec_time_seconds_key_len = strlen(AVG_EXEC_TIME_SECONDS_KEY);

    // Iterate through file
    int valid_key_count = 0;
    char buffer[BUFFSIZE] = {'\0'};
    char *curr_key;
    int i;
    char curr_char = '\0';
    int open_curly_braces_count = 0;
    int closed_curly_braces_count = 0;
    int open_bracket_count = 0;
    int closed_bracket_count = 0;
    int null_char_count = 0;
    int space_char_count = 0;
    int colon_count = 0;
    int quotes_count = 0;
    int total_valid_char_count = 0;
    int n_chars_in_key = 0;
    int line_count = 1; //yes, we start at 1
    int same_key_count = 0; //this value should always equal 1 after we've used our logic
    int index_in_key = 0;
    int e_count = 0;
    int sign_count = 0;
    int comma_count = 0;
    int dot_count = 0;

    // For checking timestamps
    char *yyyy_mm_dd_pattern = ".*([0-9]{4})\\-(0?[1-9]|1[012])\\-(0?[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|2[0-3]):([0-5]?[0-9]):([0-5][0-9]).*";
    regex_t regex;
    int reti;
    size_t nmatch = 0;
    regmatch_t pmatch[nmatch];

    while (fgets(buffer, BUFFSIZE, fftw_json_file)){

        // Check if the current key is valid and keep track of how many keys are found in the 
        // current line. We want to handle the case where there are multiple of the "correct"
        // keys in the same line, as that is invalid
        if (strstr(buffer, PERFORMANCE_KEY) != NULL){
            curr_key = PERFORMANCE_KEY;
            n_chars_in_key = performance_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, INPUTS_KEY) != NULL){
            curr_key = INPUTS_KEY;
            n_chars_in_key = input_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, RANK_KEY) != NULL){
            curr_key = RANK_KEY;
            n_chars_in_key = rank_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, DIMS_KEY) != NULL){
            curr_key = DIMS_KEY;
            n_chars_in_key = dims_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, FS_KEY) != NULL){
            curr_key = FS_KEY;
            n_chars_in_key = fs_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, ITERATIONS_KEY) != NULL){
            curr_key = ITERATIONS_KEY;
            n_chars_in_key = iterations_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, FWD_DFT_RESULTS_KEY) != NULL){
            curr_key = FWD_DFT_RESULTS_KEY;
            n_chars_in_key = fwd_dft_results_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, AVG_GFLOPS_KEY) != NULL){
            curr_key = AVG_GFLOPS_KEY;
            n_chars_in_key = avg_gflops_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, STDEV_GFLOPS_KEY) != NULL){
            curr_key = STDEV_GFLOPS_KEY;
            n_chars_in_key = stdev_gflops_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, BWD_DFT_RESULTS_KEY) != NULL){
            curr_key = BWD_DFT_RESULTS_KEY;
            n_chars_in_key = bwd_dft_results_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, AVG_EXEC_TIME_SECONDS_KEY) != NULL){
            curr_key = AVG_EXEC_TIME_SECONDS_KEY;
            n_chars_in_key = avg_exec_time_seconds_key_len;
            valid_key_count++;
        }
        if (strstr(buffer, THREADS_KEY) != NULL){
            curr_key = THREADS_KEY;
            n_chars_in_key = threads_key_len;
            valid_key_count++;
        }

        // We've found more than one 'valid' key, which means something is wrong
        if (valid_key_count > 1){
            fprintf(stderr, "Invalid key found on line %d.\n", line_count);
            return -2;
        }

        // If there is no key found, then we must check if there are balanced brackets or if the line is space
        if (valid_key_count == 0){

            reti = regcomp(&regex, yyyy_mm_dd_pattern, REG_EXTENDED);
            if (reti){
                fprintf(stderr, "Could not compile regex\n");
            }
            reti = regexec(&regex, buffer, nmatch, pmatch, 0);

            // If we have a regex match, then continue
            if (reti == 0){
                continue;
            }

            for (i=0; i<BUFFSIZE; i++){

                // Get the current character
                curr_char = buffer[i];

                // Check for spaces
                if (curr_char == ' ')
                    space_char_count++;

                // Check for null chars
                if (curr_char == '\0')
                    null_char_count++;

                // Check for open curly braces
                if (curr_char == '{')
                    open_curly_braces_count++;

                // Check for closed curly braces
                if (curr_char == '}')
                    closed_curly_braces_count++;

                // Check for commas
                if (curr_char == ',')
                    comma_count++;

                // Now see if there are multiple closed brackets on the line
                if ((open_curly_braces_count > 1) || (closed_curly_braces_count > 1)){
                    fprintf(stderr, "Too many curly braces on line %d\n", line_count);
                    return -3;
                }

                // Reset buffer by setting all chars equal to the null char
                buffer[i] = '\0';
            }
            // Count the total number of valid characters. Make sure to add +1 at the end to include the new line character (\n)
            total_valid_char_count = open_curly_braces_count + closed_curly_braces_count + space_char_count + null_char_count + comma_count + 1;
            printf("%s",buffer);
            if (total_valid_char_count != BUFFSIZE){
                fprintf(stderr, "Invalid line %d in JSON file. If the line contains a timestamp, check that the day, month, year, hour, mins, and secs are valid. Otherwise, there are unrecognized chars.\n", line_count);
                return -4;
            }
        }
        // We've found a valid key, so let's check for a colon (:) and quotes (""). We also want to make sure
        // that the colon occurs AFTER the key.
        else{

            // Now we have to check for the case if there are MULTIPLE of the same key (since we haven't checked that before)
            const char *key = buffer;
            while ((key = strstr(key, curr_key))){
                same_key_count++;
                key += strlen(curr_key);
            }

            // Now check how many of the same key we have. If we have a string such as "performance_key performance_key : {", 
            // then we know we have the same key twice in the same line and we should throw an error.
            if (same_key_count > 1){
                fprintf(stderr, "Multiple keys on line %d.\n", line_count);
                return -2;
            }

            for (i=0; i<BUFFSIZE; i++){

                // Get the current character
                curr_char = buffer[i];

                // This condition checks if the colon has been found BEFORE the current key
                if (curr_key[0] == curr_char && colon_count != 0){
                    fprintf(stderr, "Missing key on line %d.\n", line_count);
                    return -2;
                }

                // Keep track of the index of the key we're on
                if (index_in_key < n_chars_in_key){
                    if (curr_key[index_in_key] == curr_char){
                        index_in_key++;
                    }
                }

                // Check number of colons as we iterate
                if (curr_char == ':' && colon_count > 1){
                    fprintf(stderr, "Invalid key. Too many colons on line %d.\n", line_count);
                    return -2;
                }

                // Check the number of quotes as we iterate
                if (quotes_count > 2){
                    fprintf(stderr, "Invalid key. Too many quotes on line %d.\n", line_count);
                    return -2;
                }

                // Check the number of open and closed brackets in dims, as well as the comma count
                if (strcmp(curr_key, DIMS_KEY) == 0){
                    if (open_bracket_count > 1 || closed_bracket_count > 1){
                        fprintf(stderr, "Too many brackets on line %d.\n", line_count);
                        return -3;
                    }
                }
                else if (open_bracket_count != 0 || closed_bracket_count != 0){
                    fprintf(stderr, "Brackets are not allowed for key '%s' on line %d.\n", curr_key, line_count);
                    return -3;
                }
                else if ((comma_count > 1) ||
                    (strcmp(curr_key, THREADS_KEY) == 0 && comma_count != 0) ||
                    (strcmp(curr_key, STDEV_GFLOPS_KEY) == 0 && comma_count != 0)){
                    fprintf(stderr, "An excess of commas was found on line %d.\n", line_count);
                    return -5;
                }

                // If there are multiple periods, then something went wrong
                if (dot_count > 1){
                    fprintf(stderr, "An excess of '.' was found on line %d.\n", line_count);
                    return -5;
                }

                // Check if 'dims' has a period (or more) in it. By default, dims cannot have periods. The numbers must be whole.
                if ((curr_char == '.' && strcmp(curr_key, DIMS_KEY) == 0) ||
                    (curr_char == '.' && strcmp(curr_key, RANK_KEY) == 0) ||
                    (curr_char == '.' && strcmp(curr_key, THREADS_KEY) == 0) ||
                    (curr_char == '.' && strcmp(curr_key, ITERATIONS_KEY) == 0)){
                    fprintf(stderr, "Float/Double values are not allowed for '%s' line %d. Please use whole numbers.\n", curr_key, line_count);
                    return -5;
                }

                // Count the number of commas (we should have either 0 or 1 unless we're on the DIMS_KEY)
                if (curr_char == ','){
                    comma_count++;
                }
                // Count the number of periods
                else if (curr_char == '.'){
                    dot_count++;
                }
                // Count the number of colons (we only expect 1)
                else if (curr_char == ':'){
                    colon_count++;
                }
                // Count number of quotes (we only expect 2)
                else if (curr_char == '\"'){
                    quotes_count++;
                }
                // Count the number of open brackets (we only expect 1)
                else if (curr_char == '['){
                    open_bracket_count++;
                }
                // Count the number of closed brackets (we only expect 1)
                else if (curr_char == ']'){
                    closed_bracket_count++;
                }
                // We've (potentially) reached the case where there is an invalid character
                else if ((curr_char != ' ') &&
                         (curr_char != '\0') &&
                         (curr_char != '\n') &&
                         (curr_char != '{') &&
                         (curr_char != '}') &&
                         (curr_char != '.') &&
                         (curr_char != ',') &&
                         (isdigit(curr_char) == 0) &&
                         (index_in_key == n_chars_in_key) &&
                         (curr_char != curr_key[index_in_key-1])){

                        if (strcmp(curr_key, DIMS_KEY) == 0){
                            if (curr_char != ']' && curr_char != '['){
                                fprintf(stderr, "Invalid key on line %d. Unrecognized character '%c'.\n", line_count, curr_char);
                                return -2;
                            }
                        }
                        else if (strcmp(curr_key, FS_KEY) == 0){

                            // The only valid characters for fs_Hz are: digits, e, -, and +
                            if (curr_char != 'e' && curr_char != '-' && curr_char != '+'){
                                fprintf(stderr, "Invalid key on line %d. Unrecognized character '%c'.\n", line_count, curr_char);
                                return -2;
                            }
                            else if (curr_char == 'e'){
                                e_count++;
                            }
                            else if (curr_char == '+' || curr_char == '-'){
                                sign_count++;
                            }

                            // If we have too many +'s or -'s, then the format of fs is wrong.
                            if (e_count > 1 || sign_count > 1){
                                fprintf(stderr, "%s", "Invalid format for fs.\n");
                                return -6;
                            }
                        }
                        else{
                            fprintf(stderr, "Invalid key on line %d. Unrecognized character '%c'.\n", line_count, curr_char);
                            return -2;
                        }
                }

                // Reset buffer by setting all chars equal to the null char
                buffer[i] = '\0';
            }

            // Check number of quotes and colons
            if (colon_count != 1 && quotes_count != 2){
                fprintf(stderr, "Invalid key found on line %d.\n", line_count);
                return -2;
            }

        }
        // Reset indices
        index_in_key = 0;

        // Reset counts
        same_key_count = 0;
        space_char_count = 0;
        null_char_count = 0;
        open_curly_braces_count = 0;
        closed_curly_braces_count = 0;
        open_bracket_count = 0;
        closed_bracket_count = 0;
        colon_count = 0;
        quotes_count = 0;
        comma_count = 0;
        e_count = 0;
        sign_count = 0;
        dot_count = 0;

        // Update line count
        line_count++;

        // Update valid key count
        valid_key_count = 0;

    }

    regfree(&regex);
    return 0;
}
