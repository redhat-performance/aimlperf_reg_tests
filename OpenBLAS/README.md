# OpenBLAS Regression Tests

This folder contains benchmarks that test two BLAS routines: (1.) SGEMM, and (2.) DGEMM.

After you've run the benchmarks, you can run the `compare_gemm_results` executable to compare the results you get across different files.

## Table of Contents

Building OpenBLAS

  * [Building OpenBLAS on Bare Metal](#building-openblas-on-bare-metal)
  * [Building OpenBLAS on OpenShift AWS](#building-openblas-on-openshift-aws)
  * [Building OpenBLAS w/ s2i](#building-openblas-with-s2i)
  * [Building OpenBLAS w/ Podman](#building-openblas-with-podman)

Building the Tests

  * [How to Build the Tests](#how-to-build-the-tests)

Running the Tests

  * [How to Run the Tests](#how-to-run-the-tests)

Comparing Test Performance Outputs

  * [Comparing Test Results](#comparing-test-results)


## Building OpenBLAS on Bare Metal

To build OpenBLAS on bare metal, first install Ansible. You can install it via yum or dnf, or you can run

```
$ sh scripts/install_ansible_from_source.sh <ansible-git-version>
```

Once you've installed Ansible,

```
$ cd playbooks/package_installation
$ ansible-playbook -i hosts play.yaml
$ cd ../OpenBLAS_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{build_dir: /path/to/build/dir, install_dir: /path/to/install/dir, work_dir: /path/to/aimlperf_reg_tests/OpenBLAS}"
```

Alternatively, if you want to build on RHEL 8,

```
$ cd playbooks/package_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
$ cd ../OpenBLAS_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{build_dir: /path/to/build/dir, install_dir: /path/to/install/dir, work_dir: /path/to/aimlperf_reg_tests/OpenBLAS}"
```

Whether you're building on RHEL 7 or RHEL 8, OpenBLAS will be installed to `/path/to/install/dir`. There will be two folders: `lib` and `include`. You do not need to create the install directory. The ansible playbook will do that for you.


### Notes

Below are a few notes regarding Ansible

  - Run the Ansible playbooks as non-root. Running as root will most likely cause the `yumdownloader`step to **fail**
  - If running as non-root, make sure Ansible that has permissions to create a `.ansible` folder and `.ansible/tmp` folder in `/path/to/build/dir`. You can use `mkdir -p /path/to/build/dir/.ansible/tmp` to create the folders in advance and then run `chmod -R 777 /path/to/build/dir`


## Building OpenBLAS on OpenShift AWS

To build OpenBLAS on OpenShift AWS, make sure you have an OpenShift cluster you're able to use and that you have cluster admin rights. Once you've done so, expose your Docker/CRI-O registry. For example,

```
$ oc expose service image-registry -n openshift-image-registry
```

Finally,

```
$ cd OpenShift
$ sh run_me.sh
```


## Building OpenBLAS with s2i

To build OpenBLAS with the `s2i` command line tool rather than with OpenShift's s2i capabilities, make sure you have Docker and the `s2i` command line tool installed. 


### Installing Docker

For Docker on RHEL 7.x,

```
# yum -y install docker
```

For Docker on RHEL 8.x,

```
$ git clone https://github.com/docker/docker.git
$ cd docker
$ su -
# make build
# make binary
```

Make sure Docker is up and running via `systemctl start docker`

### Installing s2i

You can download the latest s2i command line tool with this command:

```
$ wget $(curl -s https://api.github.com/repos/openshift/source-to-image/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep linux-386)
```

Alternatively, you choose a different release here: https://github.com/openshift/source-to-image/releases 

Now untar it and move it to `/usr/bin`:

```
$ tar xvf source-to-image*linux-386.tar.gz
# mv s2i /usr/bin
```

### Using s2i

The first step is to build the special OpenBLAS image:

```
$ cd /path/to/aiml_perf_reg_tests
$ docker build -f OpenBLAS/Dockerfiles/Dockerfile.s2i -t openblas-rhel7 .
```

Once the image has been built, we can use `s2i`. However, make sure you are in the `.s2i` directory before calling `s2i`:

```
$ cd OpenBLAS/.s2i
$ s2i build . openblas-rhel7 openblas-dgemm-app
```

The above s2i command will build our app, which we can run using:

```
$ docker run -it openblas-dgemm-app
```

### Sample s2i Output

```
Using
default thread values.
executing. / dgemm_test 1 5 dgemm_results.json false
Using dgemm with 1 threads and 5 iterations.
executing. / dgemm_test 2 5 dgemm_results.json false
Using dgemm with 2 threads and 5 iterations.
executing. / dgemm_test 4 5 dgemm_results.json false
Using dgemm with 4 threads and 5 iterations.
PERFORMANCE RESULTS
-------------------
{
	"2019-5-6 13:51:55": {
		"inputs": {
			"gemm_type:": "dgemm",
			"iterations:": 5,
			"threads": 1,
			"matrix_params": {
				"dims": {
					"matrix_A": [16000, 16000],
					"matrix_B": [16000, 16000],
					"matrix_C": [16000, 16000]
				},
				"scalar_values": {
					"alpha": 0.10,
					"beta": 0.00
				}
			}
		},
		"performance_results": {
			"average_execution_time_seconds": 171.45410,
			"standard_deviation_seconds": 1.53879,
			"average_gflops": 47.77955
		}
	},

	"2019-5-6 14:01:07": {
		"inputs": {
			"gemm_type:": "dgemm",
			"iterations:": 5,
			"threads": 2,
			"matrix_params": {
				"dims": {
					"matrix_A": [16000, 16000],
					"matrix_B": [16000, 16000],
					"matrix_C": [16000, 16000]
				},
				"scalar_values": {
					"alpha": 0.10,
					"beta": 0.00
				}
			}
		},
		"performance_results": {
			"average_execution_time_seconds": 108.27988,
			"standard_deviation_seconds": 1.54252,
			"average_gflops": 75.65579
		}
	},

	"2019-5-6 14:09:52": {
		"inputs": {
			"gemm_type:": "dgemm",
			"iterations:": 5,
			"threads": 4,
			"matrix_params": {
				"dims": {
					"matrix_A": [16000, 16000],
					"matrix_B": [16000, 16000],
					"matrix_C": [16000, 16000]
				},
				"scalar_values": {
					"alpha": 0.10,
					"beta": 0.00
				}
			}
		},
		"performance_results": {
			"average_execution_time_seconds": 102.70730,
			"standard_deviation_seconds": 6.28957,
			"average_gflops": 79.76064
		}
	}
}
OVERALL BEST PERFORMANCE
------------------------
{
	"dgemm": {
		"profile1": {
			"matrix_info": {
				"M": 16000,
				"N": 16000,
				"K": 16000,
				"alpha": 0.10,
				"beta": 0.00
			},
			"max_performance": {
				"gflops": 79.76,
				"average_execution_time_sec": 102.71,
				"average_execution_time_stdev": 6.29,
				"timestamp": "2019-5-6 14:09:52"
			}
		}
	}
} {
	"sgemm": {}
}
```


## Building OpenBLAS with Podman

To build OpenBLAS, use one of the Dockerfiles provided in this repo. The Dockerfiles tell Podman to build OpenBLAS using rpmbuild with specific parameters. You can either (1.) use `Dockerfile.autoconfig` to autoconfigure the OpenBLAS build, or (2.) use `Dockerfile` and modify the environment variables at the top.

### RHEL 8

#### Autoconfigure the Build

`Dockerfile.autoconfig` looks at your CPU microarchitecture to determine if you need to use "HASWELL", "SKYLAKEX", "NEHALEM", "SANDYBRIDGE", etc. as your target CPU. (Default is "CORE2".) It also checks for AVX\* instructions on your machine. While OpenBLAS does have scripts to autodetect the CPU type, sometimes it cannot do it properly and will ask you to input a target CPU, causing the automated build to fail.

To build,

```
$ podman build -f Dockerfiles/Dockerfile.autoconfig --tag=rhel8_openblas_autoconfig_build
```

#### Manually Configure the Build

If you're familiar with how OpenBLAS works or you want to manually tweak parameters,

  - `AVX_CFLAGS`: Choose one or more from { `NO_AVX`, `NO_AVX2`, `NO_AVX512` }. Set an AVX flag equal to 0 if you want to use it; otherwise, 1 to disable it.
  - `TARGET_CPU`: Choose one from { `HASWELL`, `SKYLAKEX`, `NEHALEM`, `SANDYBRIDGE` }. Other, older CPUs are supported, but you'll have to look at the OpenBLAS `get_arch.c` code here: https://github.com/xianyi/OpenBLAS/blob/develop/getarch.c

To build,

```
$ podman build -f Dockerfiles/Dockerfile --tag=rhel8_openblas_custom_build
```

### RHEL 7

The RHEL 7 Dockerfile, `Dockerfile.rhel7`, does everything the `Dockerfile` and `Dockerfile.autoconfig` do, except on RHEL 7. However, it downloads the OpenBLAS source rpm via yum, rather than acquiring the source rpm from a website.

To build,

```
$ podman build -f Dockerfiles/Dockerfile.rhel7 --tag=rhel7_openblas_custom_build
```

## How to Build the Tests

First, make sure you have built and/or installed OpenBLAS. Once you have done so, you're ready to compile. To compile the SGEMM test,

```
$ sh compile_gemm.sh -g sgemm -I <path/to/openblas/include/files> -L <path/to/openblas/libs> -n <path/to/threaded/lib>
```

e.g.,

```
$ sh compile_gemm.sh -g dgemm -I /usr/include/openblas -L /usr/lib64 -n openblasp
```

For dgemm, do the same thing, except pass in `dgemm` as a value for the `-g` flag.

```
$ sh compile_gemm.sh -g dgemm -I <path/to/openblas/include/files> -L <path/to/openblas/libs> -n <path/to/threaded/lib>
```

For help on how to use the `compile_gemm.sh` command line tool, run `sh compile_gemm.sh -h`.


## How to Run the Tests

### With the Provided Script

You can use `run_benchmarks.sh` to run the benchmarks. Pass in `-h` to the script for help on how to use it. But as an example:

```
$ sh run_benchmarks.sh -e sgemm_test -i 10 -j sgemm_results.json
```

This will call the `sgemm_test` benchmark and run it on thread values equal to powers of 2, all the way up to `N = max_num_real_cores` threads. e.g., If you have 24 real cores, it'll run on 2^0, 2^1, 2^2, 2^3, ... , Max real cores.

You can pass in the `-n` flag to run everything with `numactl`.  You can also define which thread values to use by passing in the `-v` flag. e.g., `-v "2 4 5"` will run on 2, 4, and 5 threads. (Note that OpenBLAS does not appear to be thread safe for thread values NOT equal to powers of two. i.e., There is no guarantee that you won't run into a deadlock if you use a non-power-of-two.)

### Manually

For both `dgemm_test` and `sgemm_test` (which are autogenerated by the `compile_gemm.sh` script), the inputs are: (1.) number of threads, (2.) number of times to repeat the computation to get an average performance time across N computations, (3.) JSON document filename to save results to, and (4.) true/false as to whether you want to print out the JSON results after running the tests.

e.g.,

```
$ dgemm_test.sh 24 10 "dgemm_results.json" true
```

This will execute a dgemm test on 24 threads, repeating the same computation 10 times. The results will be saved to `dgemm_results.json` and printed out to the command line.


## Comparing Test Results

Let's say you have one or more JSON files outputted by `run_benchmarks.sh`, `sgemm_test`, or `dgemm_test`. You can easily compare the performance across files by running the `compare_results` executable.

To create the executable, run

```
$ sh compile_compare.sh
```

This command will generate the executable, which you can run by:

```
$ ./compare_gemm_results <number_of_files> <file1> <file2> ... <fileN>
```

If you want debug statements turned on, use the following to compile `compare.c`:

```
$ gcc src/compare.c -o compare_gemm_results -lm -Wall -DDEBUG
```
