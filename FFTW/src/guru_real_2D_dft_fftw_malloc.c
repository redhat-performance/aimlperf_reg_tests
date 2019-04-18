/* Performs a 2D *forward* DFT for 'real' data */
#define _DEFAULT_SOURCE
#include <stdlib.h>
#include <stdio.h>
//#include <time.h>
#include <sys/time.h>
#include <fftw3.h>
#include <MagickWand.h>
#include <math.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

#define BUFFSIZE 4096
#define ALIGNMENT 16   //for aligned allocation --> set to page size, NOT number of bytes in AVX* instructions
#define NITERS 1000       //number of times we should replicate the image blurring before finding an average
#define PI 3.14159265359
#define D0 3             //standard deviation for blurring --> https://en.wikipedia.org/wiki/Gaussian_blur
#define FILTER_SIZE 16   //gaussian blur filter size
#define TIMELIMIT 2      //this tells FFTW to spend no more than X seconds on finding an "acceptable" algorithm
//#define DEBUG            //to print out debug statements
//#define SAVEIMAGE        //to save the resulting blured image (this is optional)
#define IMAGE "test_images/cat.jpeg" //image to blur
//#define IMAGE "Redhat-logo-696x541.jpg"
#ifdef SAVEIMAGE
#define OUTIMAGE "test_images/check.jpeg" //output filename for the image
#endif


double G(double x, double y, double sigma){
    /*
     * This function computes G(x,y), the gaussian distribution for 2 dimensions
     */

    return (1.0 / (2.0 * PI * sigma * sigma)) * exp( -(x*x + y*y) / (2.0 * sigma * sigma));
    //return exp( -(x*x + y*y) / (2.0 * sigma * sigma));
}

void complex_multiply(double a_real, double a_complex, double b_real, double b_complex, double *real_result, double *complex_result){

    *real_result = (a_real * b_real) - (a_complex * b_complex);
    *complex_result = (a_real * b_complex) + (a_complex * b_real);
}

int nextPowerOfTwo(int n){
    /*
     * This function computes the next power of two from a value "n"
     *
     * See https://www.geeksforgeeks.org/smallest-power-of-2-greater-than-or-equal-to-n/
     */
    if (n && !(n & (n-1)))
        return n;

    unsigned count = 0;
    while (n != 0){
        n >>= 1;
        count++;
    }

    return 1 << count;
}

int main(int argc, char* argv[]){

    // Get num threads and num iterations
    int nthreads, niters;
    char *filename;
    char *pEnd;
    if (argc == 1){
        printf("Please enter number of threads to use and number of iterations to execute.\n");
        exit(0);
    }
    else if (argc == 2){
        printf("Only one argument was passed. Please pass all three arguments: (1.) number of threads, (2.) number of iterations to execute, and (3.) JSON document filename to save the results to.\n");
        exit(0);
    }
    else if (argc == 3){
        printf("Only two arguments were passed. Please pass all three arguments: (1.) number of threads, (2.) number of iterations to execute, and (3.) JSON document filename to save the results to.\n");
        exit(0);
    }
    else{

        nthreads = (int)strtol(argv[1], &pEnd, 10);
        niters = (int)strtol(argv[2], &pEnd, 10);
        filename = argv[3];

        if (nthreads < 1){
            printf("Number of threads must be greater than or equal to 1.\n");
            exit(0);
        }
        if (niters < 1){
            printf("Number of iterations must be greater than or equal to 1.\n");
            exit(0);
        }
    }

#ifdef DEBUG
        printf("<< LOADING IMAGE >>\n");
#endif
    // Initialize Magick and vars
    MagickWandGenesis();

    // Load image, while making sure it CAN be loaded
    MagickBooleanType can_load_image;
    MagickWand *magick_wand = NewMagickWand();
    can_load_image = MagickReadImage(magick_wand, IMAGE);
    if (can_load_image == MagickFalse){
        printf("Image `%s` could not be loaded. Either the image does not exist or the ImageMagick delegate does not exist. (See `magick identify -list format`.) Exiting.\n", IMAGE);
        exit(EXIT_FAILURE);
    }

    // Make sure we can iterate through the image
    PixelIterator *iterator = NewPixelIterator(magick_wand);
    if (iterator == (PixelIterator *) NULL){
        printf("Image `%s` was found, but could not be processed. Is your image corrupted? Exiting.\n", IMAGE);
        exit(EXIT_FAILURE);
    }


    PixelWand **row;
    PixelInfo pixel;

    // Vars for iterating through the image
    size_t x, y, row_width;

    // Vars for keeping track of padded vs unpadded image sizes
    int width, height;

    // Get original image height and widths, then save a copy of both
    height = MagickGetImageHeight(magick_wand);
    width = MagickGetImageWidth(magick_wand);

#ifdef DEBUG
        printf("  Image loaded. Size: %d x %d\n\n", width, height);
        printf("<< PUTTING IMAGE INTO MEMORY >>\n");
#endif

    fftw_set_timelimit(TIMELIMIT);

    // FFTW is most efficient for powers of two
    //int adjusted_height = nextPowerOfTwo(height);
    //int adjusted_width = nextPowerOfTwo(width);
    int adjusted_height = height;
    int adjusted_width = width;

#ifdef DEBUG
        printf("  Padded image size: %d x %d\n\n", adjusted_width, adjusted_height);
#endif

    // Input matrix size is simply height * width (since we're storing the matrix in a single array)
    size_t input_matrix_size = adjusted_height * adjusted_width;

    // Output matrix size would normally be height * width, too, but FFTs have a mirroring property
    // whereby FFTs are symmetrical and have redundant information. Thus, we want to take the non-
    // redundant information
    size_t output_matrix_size = (adjusted_width/2+1) * adjusted_height;

    // Let's get the size of the two matrices in bytes.
    size_t input_matrix_size_in_bytes = sizeof(double) * input_matrix_size;
    size_t output_matrix_size_in_bytes = sizeof(fftw_complex) * output_matrix_size;

    // These arrays will store our RGB colors and we use aligned_alloc to ensure AVX2 instructions run optimally
    double *red   = aligned_alloc(ALIGNMENT, input_matrix_size);
    double *green = aligned_alloc(ALIGNMENT, input_matrix_size);
    double *blue  = aligned_alloc(ALIGNMENT, input_matrix_size);
#ifdef DEBUG
        printf("<< PROCESSING IMAGE PIXELS >>\n");
#endif

    // This variable is used for converting quantum values to RGB 0-255
    int range = pow(2, 8);

    // Temporary variables. The r0_1 stands for the "red" channel being converted to a 0-1 scale,
    // rather than being on a 0-255 scale. Similar case for g0_1 and b_01.
    double r0_1, g0_1, b0_1;

    for (y=0; y<adjusted_height; ++y){

        if (y < height)
            row = PixelGetNextIteratorRow(iterator, &row_width);

        for (x=0; x<adjusted_width; ++x){

            if (x < width){
                // Get color of the pixel, which is on a "Quantum Scale"
                PixelGetMagickColor(row[x], &pixel);

                // Convert the RGB quantum colors to a [0,1] scale
                r0_1 = (double)(pixel.red   / (range * 255));
                g0_1 = (double)(pixel.green / (range * 255));
                b0_1 = (double)(pixel.blue  / (range * 255));

                // Check for rounding errors
                if (r0_1 > 1.0){
                    r0_1 = 1.0;
                }
                if (g0_1 > 1.0){
                    g0_1 = 1.0;
                }
                if (b0_1 > 1.0){
                    b0_1 = 1.0;
            }
            else{
                r0_1 = 0.0;
                g0_1 = 0.0;
                b0_1 = 0.0;
            }

            // Finally, store the values
            red[y*width + x]   = r0_1;
            green[y*width + x] = g0_1;
            blue[y*width + x]  = b0_1;
            }
        }
        PixelSyncIterator(iterator);
    }
#ifdef DEBUG
        printf("  Pixels processed. Converted from quantum scale to RGB [0,1] scale.\n\n");
        printf("<< CREATING FILTER >>\n");
#endif

    // Set up filter, and do the same with aligned_alloc for AVX2 instructions
    double *gaussian_filter = aligned_alloc(ALIGNMENT, sizeof(double) * FILTER_SIZE * FILTER_SIZE);
    double x_dist, y_dist;
    double gaussian_sum = 0.0, gaussian_value = 0.0, gaussian_max = -1.0;
    for (y=0; y<FILTER_SIZE; ++y){
        for (x=0; x<FILTER_SIZE; ++x){

            // Compute the distnace of point (x,y) from the center of the image
            x_dist = (double)(x - FILTER_SIZE/2);
            y_dist = (double)(y - FILTER_SIZE/2);

            // Compute the gaussian value
            gaussian_value = G(x_dist,y_dist,D0);

            // Keep track of the sum so that we can normalize everything afterward
            gaussian_sum += gaussian_value;

            if (gaussian_value > gaussian_max){
                gaussian_max = gaussian_value;
            }

            // Save gaussian filter
            gaussian_filter[y*FILTER_SIZE+x] = gaussian_value;
        }
    }

    // Pad filter
    double *padded_filter = malloc(input_matrix_size);

    double value = -1;
    int xf_idx = 0, yf_idx = 0;
    int right = FILTER_SIZE;
    int bottom = FILTER_SIZE;
    for (y=0; y<adjusted_height; ++y){
        for (x=0; x<adjusted_width; ++x){
            if (x >= right){
                value = 0;
            }
            else if (y >= bottom){
                value = 0;
            }
            else{
                value = gaussian_filter[yf_idx*FILTER_SIZE + xf_idx] / gaussian_sum;
                if (xf_idx >= FILTER_SIZE){
                    yf_idx++;
                    xf_idx = 0;
                }
                else{
                    xf_idx++;
                }
            }
            padded_filter[y*width+x] = value;
            value = -1;
        }
    }
#ifdef DEBUG
        printf("  Filter created.\n\n");
#endif

    // Set up timer for array creation
    struct timeval mem_start, mem_stop;

    // Set up timer for FFTs
    struct timeval fft_start, ifft_start, fft_stop, ifft_stop;

    // Set up timer for wall time
    struct timeval wall_time_start, wall_time_stop;

    // Set up timer for blurring
    struct timeval blur_start, blur_stop;

    // Create temporary variables for computing execution time
    double fft_execution_time = 0.0;
    double ifft_execution_time = 0.0;
    double blur_execution_time = 0.0;

    // Initialize variables to keep track of total time
    double total_memory_allocation_time = 0.0;
    double total_fft_execution_time = 0.0;
    double total_ifft_execution_time = 0.0;
    double total_blur_execution_time = 0.0;
    double wall_time = 0.0;

#ifdef DEBUG
        printf("<< PREPARE THREADING >>\n");
#endif
    // Set threading
    fftw_init_threads();
    fftw_plan_with_nthreads(nthreads);
#ifdef DEBUG
        printf("  FFTW is set to use %d threads.\n\n", nthreads);
        printf("<< CREATING PLANS >>\n");
#endif
    // Create plans 
    fftw_plan r_plan; //for time->frequency
    fftw_plan g_plan; //for time->frequency
    fftw_plan b_plan; //for time->frequency
    fftw_plan r_complex_plan; //for frequency->time
    fftw_plan g_complex_plan; //for frequency->time
    fftw_plan b_complex_plan; //for frequency->time
    fftw_plan filter_plan; //for FFT filter

#ifdef DEBUG
        printf("  Plans created.\n\n");
        printf("<< ESTABLISHING INPUT AND OUPUT ARRAYS >>\n");
#endif

    // Initialize input and ouput arrays for time->frequency
    double *image_r_in; //R channel input
    double *image_g_in; //G channel input
    double *image_b_in; //B channel input
    double *filter_in; //filter input
    fftw_complex *image_r_out; //R channel output (image_r_in -> DFT -> image_r_out)
    fftw_complex *image_g_out; //G channel output (image_g_in -> DFT -> image_g_out) 
    fftw_complex *image_b_out; //B channel output (image_b_in -> DFT -> image_b_out)
    fftw_complex *filter_out; //filter output

    // Initialize input and ouput arrays for frequency->time
    fftw_complex *convolved_r_in; //R channel input
    fftw_complex *convolved_g_in; //G channel input
    fftw_complex *convolved_b_in; //B channel input
    double *convolved_r_out; //R channel output
    double *convolved_g_out; //G channel output
    double *convolved_b_out; //B channel output

    // Allocate memory for Forward DFT (FFT)
    gettimeofday(&mem_start, NULL); //start clock
    image_r_in = (double*)fftw_malloc(input_matrix_size_in_bytes); image_r_out = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes);
    image_g_in = (double*)fftw_malloc(input_matrix_size_in_bytes); image_g_out = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes);
    image_b_in = (double*)fftw_malloc(input_matrix_size_in_bytes); image_b_out = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes);
    filter_in = (double*)fftw_malloc(input_matrix_size_in_bytes); filter_out = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes);

    // Allocate memory for Backward DFT (IFFT)
    convolved_r_in = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes); convolved_r_out = (double*)fftw_malloc(input_matrix_size_in_bytes);
    convolved_g_in = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes); convolved_g_out = (double*)fftw_malloc(input_matrix_size_in_bytes);
    convolved_b_in = (fftw_complex*)fftw_malloc(output_matrix_size_in_bytes); convolved_b_out = (double*)fftw_malloc(input_matrix_size_in_bytes);
    gettimeofday(&mem_stop, NULL); //start clock
    total_memory_allocation_time = (mem_stop.tv_sec - mem_start.tv_sec) * 1000.0;// sec to ms
    total_memory_allocation_time += (mem_stop.tv_usec - mem_start.tv_usec)/ 1000.0;// us to ms
    //total_memory_allocation_time *= (1.0e-3);

#ifdef DEBUG
    printf("  Arrays created. Memory allocated.\n\n");

    // Check inputs from real -> complex
    printf("  Checking validity of real pointers:\n");
    printf("  - R channel: %p (in),  %p (out)\n", image_r_in, convolved_r_out);
    printf("  - G channel: %p (in),  %p (out)\n", image_g_in, convolved_g_out);
    printf("  - B channel: %p (in),  %p (out)\n", image_b_in, convolved_b_out);
    printf("  - filter:    %p (in)\n", filter_in);

    // Check inputs from real -> complex
    printf("  Checking validity of complex pointers:\n");
    printf("  - R channel: %p (in),  %p (out)\n", image_r_out, convolved_r_in);
    printf("  - G channel: %p (in),  %p (out)\n", image_g_out, convolved_g_in);
    printf("  - B channel: %p (in),  %p (out)\n", image_b_out, convolved_b_in);

#endif

    if (!image_r_in || !image_g_in || !image_b_in || !image_r_out || !image_g_out || !image_b_out || !convolved_r_out || !convolved_g_out || !convolved_b_out || !convolved_r_in || !convolved_g_in || !convolved_b_in){
        printf("  FFTW pointer checks FAILED. One or more pointers is nil. Set DEBUG to see which pointers have failed.\n");
        exit(0);
    }

    // Checking alignments
    int in_r_alignment = (int)(((uintptr_t) image_r_in) % ALIGNMENT);
    int in_g_alignment = (int)(((uintptr_t) image_g_in) % ALIGNMENT);
    int in_b_alignment = (int)(((uintptr_t) image_b_in) % ALIGNMENT);
    int in_filter_alignment = (int)(((uintptr_t) filter_in) % ALIGNMENT);
    int out_r_alignment = (int)(((uintptr_t) red) % ALIGNMENT);
    int out_g_alignment = (int)(((uintptr_t) green) % ALIGNMENT);
    int out_b_alignment = (int)(((uintptr_t) blue) % ALIGNMENT);
    int out_filter_alignment = (int)(((uintptr_t) filter_out) % ALIGNMENT);

#ifdef DEBUG
    printf("\n  Checking pointer alignments:\n");
    if ((in_r_alignment == out_r_alignment) && (in_r_alignment == 0))
        printf("  - R channel in/out are aligned\n");
    else {
        if (in_r_alignment != 0 && out_r_alignment != 0)
            printf("  - R channel in/out are -NOT- aligned\n");
        else if (in_r_alignment == 0 && out_r_alignment != 0)
            printf("  - R channel 'in' is aligned, 'out' is -NOT- aligned\n");
        else
            printf("  - R channel 'in' is -NOT- aligned, 'out' is aligned\n");
    }
    if ((in_g_alignment == out_g_alignment) && (in_g_alignment == 0))
        printf("  - G channel in/out are aligned\n");
    else {
        if (in_g_alignment != 0 && out_g_alignment != 0)
            printf("  - G channel in/out are -NOT- aligned\n");
        else if (in_g_alignment == 0 && out_g_alignment != 0)
            printf("  - G channel 'in' is aligned, 'out' is -NOT- aligned\n");
        else
            printf("  - G channel 'in' is -NOT- aligned, 'out' is aligned\n");
    }
    if ((in_b_alignment == out_b_alignment) && (in_b_alignment == 0))
        printf("  - B channel in/out are aligned\n");
    else {
        if (in_b_alignment != 0 && out_b_alignment != 0)
            printf("  - B channel in/out are -NOT- aligned\n");
        else if (in_b_alignment == 0 && out_b_alignment != 0)
            printf("  - B channel 'in' is aligned, 'out' is -NOT- aligned\n");
        else
            printf("  - B channel 'in' is -NOT- aligned, 'out' is aligned\n");
    }
    if ((in_filter_alignment == out_filter_alignment) && (in_filter_alignment == 0))
        printf("  - Filter in/out are aligned\n");
    else
        printf("  - Filter in/out are -NOT- aligned\n");
#endif

    if ((in_r_alignment != 0) || (in_g_alignment != 0) || (in_b_alignment != 0) || (out_r_alignment != 0) || (out_g_alignment != 0) || (out_b_alignment != 0))
        printf("  WARNING: One or more RGB channels are not aligned, and improper alignment worsens performance. Set DEBUG for more info.\n");
     
    if (in_filter_alignment != 0 || out_filter_alignment != 0)
        printf("  WARNING: One or more filter channels are not aligned, and improper alignment worsens performance. Set DEBUG for more info.");

    // Variables for creating a gaussian blur
    unsigned int w, h;
    double r_real, g_real, b_real, filter_real;
    double r_imaginary, g_imaginary, b_imaginary, filter_imaginary;

    // Capture wall time
    gettimeofday(&wall_time_start, NULL); //start clock

    // This loop executes 'niters' times to represent a total of 'niters' images
    int a=0;

    for (int k=0; k<niters; k++){

#ifdef DEBUG
        if (k == 0)
            printf("\n<< BLURRING IMAGES >>\n");
#endif
        // Define plans
        r_plan = fftw_plan_dft_r2c_2d(adjusted_height, adjusted_width, image_r_in, image_r_out, FFTW_ESTIMATE);
        g_plan = fftw_plan_dft_r2c_2d(adjusted_height, adjusted_width, image_g_in, image_g_out, FFTW_ESTIMATE);
        b_plan = fftw_plan_dft_r2c_2d(adjusted_height, adjusted_width, image_b_in, image_b_out, FFTW_ESTIMATE);
        filter_plan = fftw_plan_dft_r2c_2d(adjusted_height, adjusted_width, filter_in, filter_out, FFTW_ESTIMATE);
#ifdef DEBUG
        printf("  Plans set #%d of %d successfully populated.\n", k+1, niters);
#endif

        // Fill input arrays (Note: This MUST be done AFTER we define the plans; otherwise, the FFT will fail.)
        unsigned int z;
        for (z=0; z<width*height; z++){
            image_r_in[z] = red[z];
            image_g_in[z] = green[z];
            image_b_in[z] = blue[z];
            filter_in[z] = padded_filter[z];
        }

        // Execute plans to perform forward FFT and capture time
        gettimeofday(&fft_start, NULL); //start clock
        fftw_execute(r_plan);
        fftw_execute(g_plan);
        fftw_execute(b_plan);
        gettimeofday(&fft_stop, NULL); //stop clock
        fftw_execute(filter_plan);

        // Compute execution time
        fft_execution_time = (fft_stop.tv_sec - fft_start.tv_sec) * 1000.0;// sec to ms
        fft_execution_time += (fft_stop.tv_usec - fft_start.tv_usec)/ 1000.0;// us to ms
        fft_execution_time *= (1.0e-3);

        // Update total execution time
        total_fft_execution_time += fft_execution_time;
#ifdef DEBUG
        printf("      - Forward FFT successfully executed: %0.3f sec\n", fft_execution_time);
#endif
        
        // Now let's bring the complex values back to the time domain values
        r_complex_plan = fftw_plan_dft_c2r_2d(adjusted_height, adjusted_width, convolved_r_in, convolved_r_out, FFTW_ESTIMATE);
        g_complex_plan = fftw_plan_dft_c2r_2d(adjusted_height, adjusted_width, convolved_g_in, convolved_g_out, FFTW_ESTIMATE);
        b_complex_plan = fftw_plan_dft_c2r_2d(adjusted_height, adjusted_width, convolved_b_in, convolved_b_out, FFTW_ESTIMATE);

        // Apply gaussian blur + start blur clock
        gettimeofday(&blur_start, NULL); //start clock
        unsigned int idx;
        double r_re_convolved, g_re_convolved, b_re_convolved;
        double r_im_convolved, g_im_convolved, b_im_convolved;
        for (h=0; h<height; h++){
            for (w=0; w<(width/2+1); w++){

                idx = h * (width / 2 + 1) + w;

                // Collect real values from the convolved image
                r_real = image_r_out[idx][0];
                g_real = image_g_out[idx][0];
                b_real = image_b_out[idx][0];

                // Collect imaginary values from the convolved image
                r_imaginary = image_r_out[idx][1];
                g_imaginary = image_g_out[idx][1];
                b_imaginary = image_b_out[idx][1];

                // Get real values from convolved filter
                filter_real = filter_out[idx][0];
                
                // Get complex values from the convolved filter
                filter_imaginary = filter_out[idx][1];

                // Complex multiply
                complex_multiply(r_real, r_imaginary, filter_real, filter_imaginary, &r_re_convolved, &r_im_convolved);
                complex_multiply(g_real, g_imaginary, filter_real, filter_imaginary, &g_re_convolved, &g_im_convolved);
                complex_multiply(b_real, b_imaginary, filter_real, filter_imaginary, &b_re_convolved, &b_im_convolved);

                // Save real and imaginary 'R' values
                convolved_r_in[idx][0] = r_re_convolved;
                convolved_r_in[idx][1] = r_im_convolved;

                // Save real and imaginary 'G' values
                convolved_g_in[idx][0] = g_re_convolved;
                convolved_g_in[idx][1] = g_im_convolved;

                // Save real and imaginary 'B' values
                convolved_b_in[idx][0] = b_re_convolved;
                convolved_b_in[idx][1] = b_im_convolved;

            }
        }
        // Stop blur clock
        gettimeofday(&blur_stop, NULL); //start clock

        // Compute execution time
        blur_execution_time = (blur_stop.tv_sec - blur_start.tv_sec) * 1000.0;// sec to ms
        blur_execution_time += (blur_stop.tv_usec - blur_start.tv_usec)/ 1000.0;// us to ms
        blur_execution_time *= (1.0e-3);

        // Update total execution time
        total_blur_execution_time += blur_execution_time;
#ifdef DEBUG
        printf("      - Image blurred: %0.3f sec\n", blur_execution_time);
#endif

        // Execute IFFT plans and capture execution time
        gettimeofday(&ifft_start, NULL); //start clock
        fftw_execute(r_complex_plan);
        fftw_execute(g_complex_plan);
        fftw_execute(b_complex_plan);
        gettimeofday(&ifft_stop, NULL); //stop clock

        // Compute execution time
        ifft_execution_time = (ifft_stop.tv_sec - ifft_start.tv_sec) * 1000.0;// sec to ms
        ifft_execution_time += (ifft_stop.tv_usec - ifft_start.tv_usec)/ 1000.0;// us to ms
        ifft_execution_time *= (1.0e-3);

        // Update total execution time
        total_ifft_execution_time += ifft_execution_time;
#ifdef DEBUG
        printf("      - IFFT successfully executed: %0.3f sec\n\n", ifft_execution_time);
#endif

        // Just to keep the compiler from optimizing the 'for' loops
        a++;

        }
    // Stop clock
    gettimeofday(&wall_time_stop, NULL); //stop clock

    // Compute execution time
    wall_time = (wall_time_stop.tv_sec - wall_time_start.tv_sec) * 1000.0;// sec to ms
    wall_time += (wall_time_stop.tv_usec - wall_time_start.tv_usec)/ 1000.0;// us to ms
    wall_time *= (1.0e-3);

    // Handle threading
    fftw_cleanup_threads();


    // Destroy the plan
    fftw_destroy_plan(r_plan);
    fftw_destroy_plan(g_plan);
    fftw_destroy_plan(b_plan);
    fftw_destroy_plan(filter_plan);
    fftw_destroy_plan(r_complex_plan);
    fftw_destroy_plan(g_complex_plan);
    fftw_destroy_plan(b_complex_plan);

    // Compute gigaflops
    long double fft_gflops_approx = niters / total_fft_execution_time;
    long double ifft_gflops_approx = niters / total_ifft_execution_time;

    // Get average wall times
    double average_wall_time = wall_time / (double)niters;
    double average_wall_time_excluding_blur = (wall_time - total_blur_execution_time) / (double)niters;

    // Get average blur time
    double average_blur_time = total_blur_execution_time / (double)niters;

    // Get FFT + IFFT setup times
    double overall_setup_time = wall_time - (total_fft_execution_time + total_ifft_execution_time + total_blur_execution_time);
    double single_image_setup_time = overall_setup_time / (double)niters;

    // Prepare file to save results to
    char *tmp_filename = "tmp.json";

    // Open the temporary file for writing
    FILE *tmp_file = fopen(tmp_filename, "w");

    // If there's an existing file, we'll need to open it, read it, copy the lines, then add to a new file
    bool file_exists = false;
    int i;
    if (access(filename, F_OK) != -1){

        // Change file_exists to 'true' because the file exists!
        file_exists = true;

        // Create temporary file and open
        FILE *results_file = fopen(filename, "r");

        // Iterate through all the lines to get the length of the file
        int file_length = 0;
        char buffer[BUFFSIZE] = {'\0'};
        while (fgets(buffer, BUFFSIZE, results_file))
            file_length++;
        fclose(results_file);

        // Clear buffer by setting all chars to NULL
        for (i=0; i<BUFFSIZE; i++)
            buffer[i] = '\0';

        // Now open again
        int current_line_no = 0;
        results_file = fopen(filename, "r");

        // We want to copy every single line into a temporary file EXCEPT the last line, hence "current_line_no < file_length"
        char curr_char = '\0';
        while (fgets(buffer, BUFFSIZE, results_file) && (current_line_no < file_length-2)){

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

            // Update line number
            current_line_no++;
        }
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
    fprintf(tmp_file, "                \"num_images\": %d,\n", niters);
    fprintf(tmp_file, "                \"image_dims\": [%d, %d],\n", width, height);
    fprintf(tmp_file, "                \"threads\": %d\n", nthreads);
    fprintf(tmp_file, "            },\n");
    fprintf(tmp_file, "            \"forward_dft_results\": {\n");
    fprintf(tmp_file, "                \"total_execution_time_seconds\": %0.5f,\n", total_fft_execution_time);
    fprintf(tmp_file, "                \"average_gflops\": %0.5Lf\n", fft_gflops_approx);
    fprintf(tmp_file, "            },\n");
    fprintf(tmp_file, "            \"backward_dft_results\": {\n");
    fprintf(tmp_file, "                \"total_execution_time_seconds\": %0.5f,\n", total_ifft_execution_time);
    fprintf(tmp_file, "                \"average_gflops\": %0.5Lf\n", ifft_gflops_approx);
    fprintf(tmp_file, "            },\n");
    fprintf(tmp_file, "            \"misc\": {\n");
    fprintf(tmp_file, "                \"overall_setup_time_seconds\": %0.5f,\n", overall_setup_time);
    fprintf(tmp_file, "                \"blur_time_seconds\": %0.5f,\n", total_blur_execution_time);
    fprintf(tmp_file, "                \"wall_time_without_blur_seconds\": %0.5f,\n", wall_time - total_blur_execution_time);
    fprintf(tmp_file, "                \"wall_time_seconds\": %0.5f\n", wall_time);
    fprintf(tmp_file, "            }\n");
    fprintf(tmp_file, "        }\n");
    fprintf(tmp_file, "    }\n");
    fprintf(tmp_file, "}\n");

    // Make sure to close
    fclose(tmp_file);

    // Rename the temp file
    rename(tmp_filename, filename);

    // Print out performance results
    printf("\nPERFORMANCE RESULTS\n");
    printf("===================\n");
    printf("Operations:\n");
    printf("    %d images of size %dx%d analyzed\n", niters, width, height);
    printf("    %d threads used\n", nthreads);
    printf("FFT Performance Results\n");
    printf("    %0.3Lf FFT performance GFlops\n", fft_gflops_approx);
    printf("    %0.3f sec FFT execution time\n", total_fft_execution_time * (1.0));
    printf("Inverse FFT Performance Results\n");
    printf("    %0.3Lf IFFT performance GFlops\n", ifft_gflops_approx);
    printf("    %0.3f sec IFFT execution time\n", total_ifft_execution_time * (1.0));
    printf("FFT + IFFT Setup time\n");
    printf("    Took %0.3f sec to setup %d images\n", overall_setup_time, niters);
    printf("    Took %0.3f sec to setup a single image\n", single_image_setup_time);
    printf("Blur time (non-FFTW computations)\n");
    printf("    Took %0.3f sec to blur %d images\n", total_blur_execution_time, niters);
    printf("    Took %0.3f sec to setup a single image\n", average_blur_time);
    printf("Wall time\n");
    printf("    Took %0.3f sec to blur %d images (includes non-FFTW computations)\n", wall_time, niters);
    printf("    Took %0.3f sec to blur single image (includes non-FFTW computations)\n", average_wall_time);
    printf("Wall time (excluding blur time)\n");
    printf("    Took %0.3f sec to blur %d images (only FFTW computations)\n", wall_time - total_blur_execution_time, niters);
    printf("    Took %0.3f sec to blur single image (only FFTW computations)\n\n", average_wall_time_excluding_blur);

#ifdef SAVEIMAGE
    // For savingt the image, we will need to create a few 'wands'
    MagickWand *new_image_wand = NewMagickWand();
    PixelWand *new_pixel_wand = NewPixelWand();
    PixelWand **new_row;

    // Create a new image and set it all to white
    const char *color = "white";
    PixelSetColor(new_pixel_wand, color);
    MagickNewImage(new_image_wand, width, height, new_pixel_wand);
    //new_pixel_wand = DestroyPixelWand(new_pixel_wand);

    // Initialize vars for iterating
    int _R,_G,_B;
    long double R_raw, G_raw, B_raw;
    PixelIterator *save_iterator = NewPixelIterator(new_image_wand);
    size_t xx, yy, new_row_width;
    char rgb[16];
    long double scale_factor = (long double)height * (long double)width * (long double)FILTER_SIZE * (long double)FILTER_SIZE;
    printf("\n<< Final RGB Values >>\n");
    printf("  - scale_factor = ~%0.2e\n", (double)scale_factor);
    for (yy=0; yy<height; yy++){
        new_row = PixelGetNextIteratorRow(save_iterator, &new_row_width);
            for (xx=0; xx<new_row_width; xx++){
                
                // Get the raw color
                R_raw = abs(convolved_r_out[yy*width + xx]);
                G_raw = abs(convolved_g_out[yy*width + xx]);
                B_raw = abs(convolved_b_out[yy*width + xx]);

                // Convert back to RGB
                _R = (int)(R_raw / scale_factor * 255.0 * 255.0);
                _G = (int)(G_raw / scale_factor * 255.0 * 255.0);
                _B = (int)(B_raw / scale_factor * 255.0 * 255.0);

                if (_R > 255){
                    _R = 255;
                }
                if (_G > 255){
                    _G = 255;
                }
                if (_B > 255){
                    _B = 255;
                }

                sprintf(rgb, "rgb(%d,%d,%d)", _R, _G, _B);
                PixelSetColor(new_row[xx], rgb);
            }
            PixelSyncIterator(save_iterator);
        }
    MagickWriteImage(new_image_wand, OUTIMAGE);
    DestroyMagickWand(new_image_wand);
    DestroyMagickWand(magick_wand);
    MagickWandTerminus();
#endif

    return 0;
}
