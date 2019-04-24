#include <stdio.h>
//#include "/usr/include/openblas/cblas.h"
#include <sys/time.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>

extern void openblas_set_num_threads(int num_threads);
void openblas_set_num_threads_(int* num_threads){
        openblas_set_num_threads(*num_threads);
};

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

int main(int argc, char *argv[]){

    // Check user input
    if (argc == 1){
        fprintf(stderr, "No arguments were passed. Required arguments: (1.) number of threads, (2.) number of iterations (for finding an average performance in GFlops).\n");
        exit(0);
    }
    else if (argc == 2){
        fprintf(stderr, "Too few arguments. Required arguments: (1.) number of threads, (2.) number of iterations (for finding an average performance in GFlops).\n");
        exit(0);
    }
    else if (argc > 3){
        fprintf(stderr, "Too many arguments. Required arguments: (1.) number of threads, (2.) number of iterations (for finding an average performance in GFlops).\n");
        exit(0);
    }

    // Set number of OpenBLAS threads
    char *pEnd;
    int nthreads = (int)(strtol(argv[1], &pEnd, 10));
    if (nthreads <= 0){
        fprintf(stderr, "Number of OpenBLAS threads must be a positive value. You entered %d", nthreads);
        exit(0);
    }
    openblas_set_num_threads(nthreads);

    // Set number of iterations
    int num_iters = (int)(strtol(argv[2], &pEnd, 10));
    if (num_iters <= 0){
        fprintf(stderr, "Number of iterations must be a positive value. You entered %d", num_iters);
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
        fprintf(stderr, "gemm type not defined. Please use -D when compiling this code to set gemm type. Either -DSGEMM or -DDGEMM");
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
#ifdef SGEMM
    printf("%0.3f sec sgemm execution time;  ", execution_time * (1.0));
#else
    printf("%0.3f sec dgemm execution time;  ", execution_time * (1.0));
#endif
    printf("%0.3f N operations;  ", num_ops);
    printf("%0.3f GFlops", num_ops / (execution_time / num_iters));
    printf("%s", "\n");

    return 0;
};
