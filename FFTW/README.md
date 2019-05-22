# FFTW Regression Tests

This folder contains regression tests to assess the performance of FFTW's forward and backward FFTs by performing an image blurring task.

## Building FFTW

### Bare Metal

To build FFTW on bare metal, first install Ansible. You can install it via yum or dnf, or you can run

```
$ sh scripts/install_ansible_from_source.sh <ansible-git-version>
```

Once you've installed Ansible,

```
$ cd playbooks/package_installation
$ ansible-playbook -i hosts play.yaml
$ cd ../FFTW_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{build_dir: /path/to/build/dir, install_dir: /path/to/install/dir}"
```

Alternatively, if you want to build on RHEL 8,

```
$ cd playbooks/package_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
$ cd ../FFTW_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{build_dir: /path/to/build/dir, install_dir: /path/to/install/dir"
```

Whether you're building on RHEL 7 or RHEL 8, FFTW will be installed to `/path/to/install/dir`. There will be two folders: `lib` and `include`. You do not need to create the install directory. The ansible playbook will do that for you.

### Podman

If you decide to use Podman, make note of the `FFTW_CFLAGS` and `FFTW_BUILD_FLAGS` environment variables in the Dockerfile. These variables determine which build flags FFTW will be configured to use. Once you've chosen your flags, make sure to add your `.repo` files to the `repos` folder under the root of this repo. (See the `README.md` file under the `repos` folder for how to create the `.repo` files.) Once that is all said and done, you can build the image via:

```
$ podman build -f Dockerfiles/Dockerfile.[name]
```

where `[name]` is either `rpmbuild_only` or `rpmbuild_regression_tests`. The first, as the name says, only builds the FFTW rpms. The second also builds the FFTW rpms, but then adds and runs the regression tests.

Note that, for either Dockerfile, `rpmbuild` builds and executes unit tests on the FFTW library upon completion of the build. These unit tests tend to be the longest part of the FFTW build.

If you wish to build `Dockerfile.rpmbuild_regression_tests` *and* use `numactl` for running the regression tests (since numactl can boost performance), you'll need to: (1.) Pass in the numactl seccomp profile under `seccomp_profiles` and (2.) pass in the build argument for the flag `use_numactl`. That is,

```
$ podman build -f Dockerfiles/Dockerfile.rpmbuild_regression_tests --security-opt="seccomp=seccomp_profiles/numactl_seccomp.json" --build-arg use_numactl="true"
```

This seccomp file was written by w1ndy to avoid the need to use `--privileged` with `numactl`: https://gist.github.com/w1ndy/4aee49aa3a608c977a858542ed5f1ee5

### Installation Scripts

If you would like to use the installation scripts, you can run either `build.sh` or `install.sh` to build the library, but of course `install.sh` will also install the generated rpms for you. See

```
$ sh build.sh -h
```

for help on how to use the build script. Similarly, use

```
$ sh install.sh -h
```

for help on how to use the install script.

Note that if you wish to build FFTW while using root, you will need to use the `-s` flag in both scripts to override the automatic exit. (The exit is for protection.) Also, a list of the required packages can be found within the  `build.sh` script

## How to Build the Tests

To build the tests,

```
$ . ./compile_benchmark_code.sh /path/to/main/fftw/folder
```

This command will generate two executables: `2d_fft` and `nd_cosine_ffts`. The first executable, `2d_fft`, blurs an image by performing a forward 2D DFT on an image, then carrying out complex number computations on the image in the frequency domain, and finally, running a backward 2D DFT on the image blurred in the frequency domain. The second executable performs an n-dimensional forward FFT and an n-dimensional backward FFT on an n-dimensional cosine matrix.

Both executables require user inputs to define the number of FFTW threads to use, how many times we want to execute the same computation (to get an average performance in seconds and GFlops), etc.. See the next section for more details.

## How to Run the Tests

### Using the Existing Shell Script

To run the tests with the `run_benchmarks.sh` script,

```
$ ./run_benchmarks.sh -i <number_of_iterations> -e <executable> -j <json_file_name> [options]
```

where `<executable>` is either `2d_fft` or `nd_cosine_ffts`-- each of which you must have already compiled with `compile_benchmarks.sh`.

Note that for `nd_cosine_ffts`, there are additional required flags. See `./run_benchmarks.sh -h` for help and more info on the options available.

This tool is useful because it allows you to run a series of benchmark tests with one command, rather than running everything by hand multiple times. It also saves all of the runs to a log file, defined by the user with the `-l` option.

Example for `2d_fft`:

```
$ ./run_benchmarks.sh -i 1000 -e 2d_fft -v "2 4 9" -j "fftw_image_blur_performance_results.json"
```

This command will run the `2d_fft` executable on 2, 4, and 9 threads, and for each thread count (i.e., 2, 4, and 9), it will process 1000 images to obtain a "good" average. All performance results will be saved to `fftw_image_blur_performance_results.json`. See the *Sample Outputs* section below for an example layout of the JSON document.

If you do not specify a list of thread counts, you can simply run

```
$ ./run_benchmarks.sh -i 1000 -e 2d_fft -j "fftw_image_blur_performance_results.json"
```

The script will automatically detect the maximum number of *real* cores on your machine via an `lscpu` command, and it will start with a thread count of 1, increasing by powers of 2 until you reach the max number of real cores. That is, for a machine with 28 real cores, `run_benchmark.sh` will run `2d_fft` on 1 thread, 2 threads, 4 threads, 8 threads, 16 threads, and 28 threads.

Example for `nd_cosine_ffts`:

```
$ ./run_benchmarks.sh -e nd_cosine_ffts -i 14 -r 2 -f 0.001 -d "300 300" -j "fftw_cosine_performance_results.json"
```

This command will run the `nd_cosine_ffts` on fourteen 2D cosine matrices--each dimension being 300 in size--with a sampling frequency `Fs=0.001`, and it will save the performance results to `fftw_cosine_performance_results.json`. Since the `-v` option wasn't used, again, the thread values will be powers of 2, up to the maximum number of real cores on your system.

To optimize performance, you can use the `-n` option to enable `numactl`. If the `-v` option is not passed to the benchmark script, then `numactl` will run up to a maximum of "\# of real cores" threads to avoid running on hyperthreads. But remember, to use numactl in Podman, you'll have to pass in the seccomp profile. (See the **Building FFTW** section at the top of this document for more info.)

### Running by Hand

To run the image blurring test by hand,

```
$ ./2d_fft <number-of-threads> <number-of-executions> <json-document-filename>
```

e.g.,

```
$ ./2d_fft 24 2 "fftw_image_blur_performance_results.json"
```

will execute the tests two times spread across twenty four threads and save the performance results to `fftw_image_blur_performance_results.json`.

To run the cosine FFT tests by hand,

```
$ ./nd_cosine_ffts "noplot" "test.json" 24 10 0.00001 2 30000 30000 
```

The `"noplot"` parameter tells the executable not to plot the results. If you want to plot the results, however, change `"noplot"` to `"plot"`--but make sure you have gnuplot installed! Look for `test.json` to see performance results.

If you want a quick rundown of parameter info, simply run

```
$ ./nd_cosine_ffts
```

This will throw an error, but the error will tell you all the parameters that are required and in what order.


## Plotting Cosine Performance Test Outputs from JSON

To plot cosine performance results from a given JSON file, first make sure you have gnuplot installed on your machine. Once you have confirmed that you have gnuplot installed, run `compile_benchmark_code.sh` to generate the benchmark executables and the plotting executable. Then run the benchmark tests on `nd_cosine_ffts` (preferably using `run_benchmarks.sh`). Once these steps are completed, run:

```
$ ./plot_cosine_performance <your-json-file>
```

...and you should see two plots generated (technically 1 plot with 2 subplots): one for Forward DFT performance results and one for backward DFT performance results. Each data point has a label so that you know what the value is at that point. Also, the sampling frequency `fs` and dimensions of the cosine matrix are plotted.

Sample plot below:

![Sample cosine DFT performance results plot](sample_plots/sample_cosine_perf_plot.jpg?raw=true "Sample Cosine DFT Performance Results Plot")

## Sample Outputs

Below are sample outputs from each FFTW test set.

### Image Blurring

**stdout**

The layout of the stdout is shown below. Here is a brief overview of what you're looking at:

  - FFT Performance Results: Performance results for forward DFTs
    - "GFlops" represents the number of gigaflops for executing a single forward DFT
    - "FFT execution time" represents the *total* time it takes to perform forward DFTs on **N** images
  - IFFT Performance Results: Performance results for backward DFTs
    - "GFlops" --> Same as above, except for backward DFT
    - "IFFT execution time" --> same as above, except for backward DFTs
  - FFT + IFFT Setup Time: Total time it takes to set up the FFTs (this involves FFTW object creation/initialization)
  - Blur time: Is a **non-FFTW computation**. Blurring is NOT done with FFTW since FFTW does not have that capability. Thus, "blur time" is pure C code that I wrote
  - Wall time: Total wall time, including image blurring
  - Wall time (excluding blur time): Wall time when you remove the non-FFTW blurring computations


```
PERFORMANCE RESULTS
===================
Operations:
    2 images of size 2392x2500 analyzed
    24 threads used
FFT Performance Results
    26.112 FFT performance GFlops
    0.077 sec FFT execution time
Inverse FFT Performance Results
    23.066 IFFT performance GFlops
    0.087 sec IFFT execution time
FFT + IFFT Setup time
    Took 0.274 sec to setup 2 images
    Took 0.137 sec to setup a single image
Blur time (non-FFTW computations)
    Took 0.098 sec to blur 2 images
    Took 0.049 sec to setup a single image
Wall time
    Took 0.535 sec to blur 2 images (includes non-FFTW computations)
    Took 0.268 sec to blur single image (includes non-FFTW computations)
Wall time (excluding blur time)
    Took 0.437 sec to blur 2 images (only FFTW computations)
    Took 0.219 sec to blur single image (only FFTW computations)
```

**JSON out**

```
{
    "2019-3-19 8:14:43": {
        "performance_results": {
            "inputs": {
                "num_images": 14,
                "image_dims": [2392, 2500],
                "threads": 16
            },
            "forward_dft_results": {
                "total_execution_time_seconds": 0.49642,
                "average_gflops": 28.20164
            },
            "backward_dft_results": {
                "total_execution_time_seconds": 0.54755,
                "average_gflops": 25.56830
            },
            "misc": {
                "overall_setup_time_seconds": 1.31261,
                "blur_time_seconds": 0.57199,
                "wall_time_without_blur_seconds": 2.35659,
                "wall_time_seconds": 2.92858
            }
        }
    },

    "2019-3-19 8:14:47": {
        "performance_results": {
            "inputs": {
                "num_images": 14,
                "image_dims": [2392, 2500],
                "threads": 32
            },
            "forward_dft_results": {
                "total_execution_time_seconds": 0.43672,
                "average_gflops": 32.05752
            },
            "backward_dft_results": {
                "total_execution_time_seconds": 0.48208,
                "average_gflops": 29.04112
            },
            "misc": {
                "overall_setup_time_seconds": 1.42608,
                "blur_time_seconds": 0.52971,
                "wall_time_without_blur_seconds": 2.34487,
                "wall_time_seconds": 2.87458
            }
        }
    }
}

```

### Cosine FFTs

**stdout**

  - Input info: 
    - A one n-dimensional cosine matrix of size **M x N** samples
    - fs: Sampling frequency (you'll want to use a smaller number for larger matrices if you want to visualize nice cosine curves)
    - Number of times we process our n-dimensional cosine matrix
    - Number of threads used
  - DFT Results:
    - Forward DFT execution time: Average execution time for a forward DFT on our n-dimensional cosine matrix
    - Forward DFT TFlops: Average number of teraflops for a forward DFT
    - Backward DFT execution time: Same as Forward DFT execution time, except for backward DFTs
    - Backward DFT Tflops: Average number of teraflops for a backward DFT

```
PERFORMANCE RESULTS
===================
Input Info:
    One 2D cosine: 30000 x 30000 samples
    fs = 1.00e-03 Hz
    14 iterations
    24 threads used
DFT Results
    Forward DFT execution time: 1.698 sec 
    Forward DFT TFlops: 3591.624
    Backward DFT execution time: 1.784 sec 
    Backward DFT TFlops: 3419.213

```

**JSON out**

```
{
    "2019-3-19 7:40:8": {
        "performance_results": {
            "inputs": {
                "rank": 2,
                "dims": [ 300, 300],
                "fs_Hz": 1.00e-03,
                "iterations": 14, 
                "threads": 16
            },
            "forward_dft_results": {
                "average_execution_time_seconds": 0.00030,
                "average_tflops": 24774.93799
            },
            "backward_dft_results": {
                "average_execution_time_seconds": 0.00016,
                "average_tflops": 47043.15585
            }
        }
    },  

    "2019-3-19 7:40:8": {
        "performance_results": {
            "inputs": {
                "rank": 2,
                "dims": [ 300, 300],
                "fs_Hz": 1.00e-03,
                "iterations": 14, 
                "threads": 24
            },
            "forward_dft_results": {
                "average_execution_time_seconds": 0.00050,
                "average_tflops": 14675.60021
            },
            "backward_dft_results": {
                "average_execution_time_seconds": 0.00024,
                "average_tflops": 31343.14253
            }
        }
    }   
}

```
