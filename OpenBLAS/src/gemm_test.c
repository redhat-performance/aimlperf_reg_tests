#include <stdio.h>
//#include "/usr/include/openblas/cblas.h"
#include <sys/time.h>
#include <time.h>
#include <sys/time.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

extern void openblas_set_num_threads(int num_threads);
void openblas_set_num_threads_(int* num_threads){
        openblas_set_num_threads(*num_threads);
};

/***************************************************/
// Define params for iterating through JSON document
#define BUFFSIZE 4096

/***************************************************/
// Define m, n, and k. [A = (m x k) matrix, B = (k x n) matrix]
#define M 16000
#define N 16000
#define K 16000

// Define alpha and beta. [We compute alpha * A * B + beta * C]
#define ALPHA 0.1
#define BETA 0.0

// Initialize matrices such that c = A * B
#ifdef SGEMM
static float a[M * K];
static float b[K * N];
static float c[M * N];
#elif DGEMM
static double a[M * K];
static double b[K * N];
static double c[M * N];
#endif

/***************************************************/
// For checking if an input is a number of not
// SOURCE: https://stackoverflow.com/a/29248688/7093236
bool input_is_positive_number(char number[]){
    int i = 0;
    if (number[0] == '-')
        return false;

    for (; number[i] != 0; i++){
        if (number[i] > '9' || number[i] < '0')
            return false;
    }
    return true;
};

/***************************************************/
// Fills an array with random numbers
void fill_float_arr(float *arr, int arr_len){
    int i;
    srand(time(NULL));
    for(i=0; i<arr_len; i++){
        float val = (float)(rand() % 1000);
        arr[i] = val;
    }
    return;
};

void fill_double_arr(double *arr, int arr_len){
    int i;
    srand(time(NULL));
    for(i=0; i<arr_len; i++){
        double val = (double)(rand() % 1000);
        arr[i] = val;
    }
    return;
};

/***************************************************/
// Prints JSON results
void print_JSON_results(char *JSON_doc_filename, int linestart){

    // Define buffer
    char buffer[BUFFSIZE] = {'\0'};

    // Save line count
    int linecount = 0;

    // Open file
    FILE *JSON_doc = fopen(JSON_doc_filename, "r");

    printf("{\n");
    while (fgets(buffer, BUFFSIZE, JSON_doc)){
        linecount++;
        if (linecount < linestart)
            continue;
        printf("%s", buffer);
    }
};
/***************************************************/

int main(int argc, char *argv[]){

    // Check user input
    char *required_args_error_str = "Required arguments: (1.) number of threads, (2.) number of iterations (for finding an average performance in GFlops), (3.) JSON filename to save results to (you can input either input an existing filename or a new filename), (4.) true/false for printing JSON results after successful completion of the script";
    if (argc == 1){
        fprintf(stderr, "No arguments were passed. %s.\n", required_args_error_str);
        exit(0);
    }
    else if (argc < 5){
        fprintf(stderr, "Too few arguments. %s.\n", required_args_error_str);
        exit(0);
    }
    else if (argc > 5){
        fprintf(stderr, "Too many arguments. %s.\n", required_args_error_str);
        exit(0);
    }

    // Set number of OpenBLAS threads
    long num_procs =  sysconf(_SC_NPROCESSORS_ONLN);
    bool openblas_threads_is_positive_number = input_is_positive_number(argv[1]);
    char *pEnd;
    int nthreads;
    if (openblas_threads_is_positive_number == true){
        nthreads = (int)(strtol(argv[1], &pEnd, 10));
        if (nthreads > num_procs){
            fprintf(stderr, "You entered more threads than your machine can use. Exiting to prevent overthreading.\n");
            exit(0);
        }
        openblas_set_num_threads(nthreads);
    }
    else{
        fprintf(stderr, "OpenBLAS threads must be a positive number. You entered: %s\n", argv[1]);
        exit(0);
    }

    // Set number of iterations
    bool num_iters_is_positive_number = input_is_positive_number(argv[2]);
    int num_iters;
    if (num_iters_is_positive_number == true){
        num_iters = (int)(strtol(argv[2], &pEnd, 10));
    }
    else{
        fprintf(stderr, "Number of threads must be a positive number. You entered: %s\n", argv[2]);
        exit(0);
    }

    // Set filename
    char *gemm_JSON_filename = argv[3];
    
    // Decide whether to print JSON docs or not
    char *JSON_print = argv[4];
    bool print_results;
    if (strcmp(JSON_print, "true") == 0){
        print_results = true;
    }
    else if (strcmp(JSON_print, "false") == 0){
        print_results = false;
    }
    else{
        fprintf(stderr, "Please define whether to print the JSON results. Set parameter #4 equal to \"true\" or \"false\"\n");
        exit(0);
    }

    // Check if user defined the GEMM_TYPE macro
#ifdef SGEMM
        // Let user know they're using SGEMM
        printf("Using sgemm with %d threads and %d iterations.\n", nthreads, num_iters);

        // Initialize arrays 'a' and 'b' to random floats
        fill_float_arr(a, M * K);
        fill_float_arr(b, K * N);
#elif DGEMM
        // Let user know they're using SGEMM
        printf("Using dgemm with %d threads and %d iterations.\n", nthreads, num_iters);

        // Initialize arrays 'a' and 'b' to random doubles
        fill_double_arr(a, M * K);
        fill_double_arr(b, K * N);
#else
        fprintf(stderr, "gemm type not defined. Please use -D when compiling this code to set gemm type. Either -DSGEMM or -DDGEMM\n");
        exit(0);
#endif

    // Initialize arr 'c' to zeros
    int i;
    for (i=0; i<(M*N); i++){
        c[i] = 0.0;
    }

    // Set LDA, LDB, and LDC
    int LDA = M;
    int LDB = K;
    int LDC = M;

    // Compute sgemm while getting execution time
    struct timeval start, stop, result;
    double execution_time;
    double execution_time_ms;

    int count = 1;
#ifdef SGEMM
        // Start clock
        gettimeofday(&start, NULL);
        for (i=0; i<num_iters; i++){

            // Compute sgemm
            cblas_sgemm(CblasColMajor,
                        CblasNoTrans,
                        CblasNoTrans,
                        M,
                        N,
                        K,
                        ALPHA,
                        a,
                        LDA,
                        b,
                        LDB,
                        BETA,
                        c,
                        LDC);

            // Dummy value to prevent the compiler from optimizing the loop
            count += count * 4 / 3;
        }

        // Stop clock
        gettimeofday(&stop, NULL);
#else
        // Start clock
        gettimeofday(&start, NULL);
        for (i=0; i<num_iters; i++){

            // Compute dgemm
            cblas_dgemm(CblasColMajor,
                        CblasNoTrans,
                        CblasNoTrans,
                        M,
                        N,
                        K,
                        ALPHA,
                        a,
                        LDA,
                        b,
                        LDB,
                        BETA,
                        c,
                        LDC);

            // Dummy value to prevent the compiler from optimizing the loop
            count += count * 4 / 3;
        }

        // Stop clock
        gettimeofday(&stop, NULL);
#endif

    // Compute execution time
    execution_time = (stop.tv_sec - start.tv_sec) * 1000.0;
    execution_time += (stop.tv_usec - start.tv_usec) / 1000.0;
    execution_time *= (1.0e-3);

    // Compute GFlops
    double num_ops = (2.0 * M * N * K) / (1e9);
    double gflops_approx = num_ops / (execution_time / num_iters);

    // Save results to file
    FILE *tmp_gemm_JSON_doc = fopen("tmp_gemm_results.json", "w");
    bool gemm_JSON_document_exists = false;
    int linestart = 0; //this is used for printing the JSON results
    if (access(gemm_JSON_filename, F_OK) != -1){
        
        // Set "gemm_JSON_document_exists" equal to "true" so that we know we already have a file
        gemm_JSON_document_exists = true;

        // Setup buffer for iterating through the file
        char buffer[BUFFSIZE] = {'\0'};

        // Open results file
        FILE *existing_gemm_results_doc = fopen(gemm_JSON_filename, "r");

        // We want to copy every single line into a temporary file EXCEPT the last line, hence "current_line_no < file_length"
        char curr_char = '\0';
        while (fgets(buffer, BUFFSIZE, existing_gemm_results_doc)){

            // The second to last line in the file will end with "    }", so if we see this case, then we stop the loop.
            if (buffer[0] == ' ' && buffer[1] == ' ' && buffer[2] == ' ' && buffer[3] == ' ' && buffer[4] == '}' && buffer[5] != ',')
                break;

            // Iterate through all the characters in 'buffer'
            for (i=0; i<BUFFSIZE; i++){

                // Get current character
                curr_char = buffer[i];

                // If the last character is not "\n", then it means we still have characters that we need to write to the file
                if (curr_char != '\0')
                    fputc(curr_char, tmp_gemm_JSON_doc);

                // Clear buffer
                buffer[i] = '\0';
            }
            linestart++;
        }

        // Finally,
        fprintf(tmp_gemm_JSON_doc, "    },\n");
        linestart += 3;
    }

    // Get current timestamp
    time_t raw_time = time(NULL);
    struct tm *timeinfo = localtime(&raw_time);

    // Get year, month, day, hours, mins, seconds
    int year = timeinfo->tm_year + 1900;
    int month = timeinfo->tm_mon + 1;
    int day = timeinfo->tm_mday;
    int hour = timeinfo->tm_hour;
    int min = timeinfo->tm_min;
    int sec = timeinfo->tm_sec;

    char min_str[2];
    if (min < 10){
        min_str[0] = '0';
        min_str[1] = min + '0';
    }
    else{
        min_str[1] = (min % 10) + '0';
        min_str[0] = (min - (min % 10)) / 10 + '0';
    }

    char sec_str[2];
    if (sec < 10){
        sec_str[0] = '0';
        sec_str[1] = sec + '0';
    }
    else{
        sec_str[1] = (sec % 10) + '0';
        sec_str[0] = (sec - (sec % 10)) / 10 + '0';
    }

    // Start saving results to file
    if (gemm_JSON_document_exists == false)
        fprintf(tmp_gemm_JSON_doc, "{\n");
    else
        fprintf(tmp_gemm_JSON_doc, "\n");
    fprintf(tmp_gemm_JSON_doc, "    \"%d-%d-%d %d:%c%c:%c%c\": {\n", year, month, day, hour, min_str[0], min_str[1], sec_str[0], sec_str[1]);
    fprintf(tmp_gemm_JSON_doc, "        \"inputs\": {\n");
#ifdef SGEMM
    fprintf(tmp_gemm_JSON_doc, "            \"gemm_type:\": \"sgemm\",\n");
#else
    fprintf(tmp_gemm_JSON_doc, "            \"gemm_type:\": \"dgemm\",\n");
#endif
    fprintf(tmp_gemm_JSON_doc, "            \"iterations:\": %d,\n", num_iters);
    fprintf(tmp_gemm_JSON_doc, "            \"threads\": %d,\n", nthreads);
    fprintf(tmp_gemm_JSON_doc, "            \"matrix_params\": {\n");
    fprintf(tmp_gemm_JSON_doc, "                \"dims\": {\n");
    fprintf(tmp_gemm_JSON_doc, "                    \"matrix_A\": [%d,%d],\n", M, K);
    fprintf(tmp_gemm_JSON_doc, "                    \"matrix_B\": [%d,%d],\n", K, N);
    fprintf(tmp_gemm_JSON_doc, "                    \"matrix_C\": [%d,%d]\n", M, N);
    fprintf(tmp_gemm_JSON_doc, "                },\n");
    fprintf(tmp_gemm_JSON_doc, "                \"scalar_values\": {\n");
    fprintf(tmp_gemm_JSON_doc, "                    \"alpha\": %0.2f,\n", ALPHA);
    fprintf(tmp_gemm_JSON_doc, "                    \"beta\": %0.2f\n", BETA);
    fprintf(tmp_gemm_JSON_doc, "                }\n");
    fprintf(tmp_gemm_JSON_doc, "            }\n");
    fprintf(tmp_gemm_JSON_doc, "        },\n");
    fprintf(tmp_gemm_JSON_doc, "        \"performance_results\": {\n");
    fprintf(tmp_gemm_JSON_doc, "            \"average_execution_time_seconds\": %0.5f,\n", execution_time / num_iters);
    fprintf(tmp_gemm_JSON_doc, "            \"average_gflops\": %0.5f\n", gflops_approx);
    fprintf(tmp_gemm_JSON_doc, "        }\n");
    fprintf(tmp_gemm_JSON_doc, "    }\n");
    fprintf(tmp_gemm_JSON_doc, "}\n");

    // Make sure to close file!
    fclose(tmp_gemm_JSON_doc);

    // Rename file
    rename("tmp_gemm_results.json", gemm_JSON_filename);

    // Print JSON results?
    if (print_results == true)
        print_JSON_results(gemm_JSON_filename, linestart);

    return 0;
};
