#!/bin/bash

FFTW_LIB=$1

# For linking to FFTW3 libraries + ImageMagick
export LD_LIBRARY_PATH=${FFTW_LIB}/double/.libs:${FFTW_LIB}/double/threads/.libs:/usr/local/lib

# Compile
gcc -O  src/guru_real_2D_dft_fftw_malloc.c -std=c11 -Wall -o 2d_fft -I/usr/include -I${FFTW_LIB}/api -L${FFTW_LIB}/double/.libs -L${FFTW_LIB}/double/threads/.libs -lfftw3 -lfftw3_threads -lm -lpthread -I/usr/local/include/ImageMagick-7 -I/usr/local/include/ImageMagick-7/MagickWand -L/usr/local/lib -lMagickCore-7.Q16HDRI -lMagickWand-7.Q16HDRI -DMAGICKCORE_QUANTUM_DEPTH=16 -DMAGICKCORE_HDRI_ENABLE=0
gcc -O  src/multidimensional_cosine_dft.c -mcmodel=large -shared-libgcc -std=c11 -Wall -o nd_cosine_ffts -I/usr/include -I${FFTW_LIB}/api -L${FFTW_LIB}/double/.libs -L${FFTW_LIB}/double/threads/.libs -lfftw3 -lfftw3_threads -lm -lpthread
gcc -O  src/plot_multidimensional_cosine_performance_results.c -std=c11 -Wall -o plot_cosine_performance -lm
