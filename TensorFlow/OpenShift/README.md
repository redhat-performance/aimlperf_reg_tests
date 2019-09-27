# OpenShift Files

## Overview

This folder contains files used for launching the [official TensorFlow High-Performance CNN benchmarks](https://github.com/tensorflow/benchmarks/tree/master/scripts/tf_cnn_benchmarks) as an app in OpenShift on AWS. If you wish to build and run TensorFlow on RHEL 8, follow the instructions in the next section carefully. They are required. Otherwise, for RHEL 7 builds, you can skip to the **Basics** section.

## Using redhat.io Images (REQUIRED FOR NON-CUDA RHEL 8 BUILDS)

For RHEL 8, you will need to use one of the images located in the container catalog, under the name registry.redhat.io.

To use images from the redhat.io image registry, you will need to do the following:

  1. Download your secret. The "secret" should be named something along the lines of "<your-username>-secret.yaml" and save it to `../../secrets`.
  2. Submit your secret to the cluster
  3. Create a template with `setup/images/rhel8_s2i_image_buildconfig.yaml` to add the image to the repository
  4. Import the image

For more information on (1.) and how to acquire a secret, visit [The Container Catalog](https://access.redhat.com/containers/). The YAML file should look something like this:

```
apiVersion: v1
kind: Secret
metadata:
  name: 1234567-USERNAME-pull-secret
data:
  .dockerconfigjson: <hash>
type: kubernetes.io/dockerconfigjson
```

but `1234567` will be a very specific 7-digit ID number, `USERNAME` is your registry username, and `<hash>` is a long string that contains your secret for accessing the redhat.io registry.

You should save this file as `../../secrets/redhat_io_registry.yaml`. Now run:

```
$ sh setup/images/add_registry_secret.sh
```

## Preparing for CUDA Builds (REQUIRED FOR CUDA BUILDS!!)

To prepare for CUDA builds, you will first need to create an EBS volume, like so:

```
$ cd setup/volumes
$ sh create_ebs_volume.sh -n <volume_name> -t <volume_type> -s <volume_size> -z <aws_availability_zone>
```

Once you've created your volume, create a dummy pod that will be used for storing data in the EBS storage via a PV (Persistent Volume):

```
$ #cd setup/volumes
$ sh create_temp_pod.sh <volume_id>
```

This will create a temporary pod named `tmp-nvidia-pod`, which you can access by executing:

```
$ oc exec -it tmp-nvidia-pod -- /bin/bash
```

The EBS volume will be mounted under `/tmp/nvidia_ebs`. From there, you can download your two (required) NVIDIA packages: (1.) NCCL, and (2.) cuDNN.

If you have an s3 bucket where the packages are stored, then install `awscli` via `pip` or `pip3`, configure it to provide your credentials, and download. Otherwise, download from wherever you have your tarballs hosted.

Once you're done, type `exit` to exit the pod. Because you won't be needing it anymore, you can delete it via:

```
$ oc delete pod/tmp-nvidia-pod
```

Now you're all set! The EBS volume should have your cuDNN and NCCL tar files!


## Basics

To run, first make sure you've set up an OpenShift AWS instance and exposed your image registry (Docker, CRI-O, etc.). The instance can be either a CPU or GPU type. Once your OpenShift AWS is ready, run:

```
$ sh run_me.sh -v <rhel_version> -v <blas_backend_to_use> -d <num_devices_to_use>
```

e.g.,

```
$ sh run_me.sh -v 7 -b fftw -d 24
```

or 

```
$ sh run_me.sh -v 8 -b fftw -d 24
```

The above command will load the templates from the `templates` folder into a random AWS instance, create a build image special for the TensorFlow benchmarks, then run the benchmarks on the number of CPUs specified by `-d`.

Note that the default C compiler that will be used to build FFTW, NumPy, and TensorFlow is set to `/usr/bin/gcc`. If you're building a RHEL 7 image (i.e., not RHEL 8) and wish to use a *different* `gcc` installation such that you can build with AVX512\* instructions, use the `-c` option to pass in its path. (Note: this is not the gcc on your machine, but rather, the gcc that is in your s2i image.)

## How it Works

By default, your OpenShift image will be named `tensorflow-rhel7` for RHEL 7 or `tensorflow-rhel8` for RHEL 8, and will be saved to your exposed OpenShift image registry. (NOTE: You don't need to tell the `run_me.sh` script the link to your registry since the script automatically determines the link for you. However, if you have *multiple* registries for whatever reason, you may want to edit which registry to use. So, edit the `REGISTRY` variable.)

You can run `run_me.sh` multiple times if you want. It is safe to do so, as it cleans up the environment every time you want to start a new build.


## Advanced Usage: Node Feature Discovery

Note that if you want to build using [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery/) and run on a specific node, make sure you have it installed/deployed it prior to running the main script in this folder (`run_me.sh`).

To deploy the NFD Operator,

```
$ sh ../../helper_scripts/OpenShift/nfd_setup.sh
```

Once the above operator has been deployed, run one of the the following commands to define which instance you would like to run the app on:

```
$ sh run_me.sh -v 7 -b <blas_backend_to_use> -n -t <instance_type> -d <num_devices_to_use> [optional args]
```

or

```
$ sh run_me.sh -v 7 -b <blas_backend_to_use> -n -x <avx_instruction_set_name> -d <num_devices_to_use> [optional args]
```

(And of course, you can use RHEL 8 instead of RHEL 7 by passing in the value `8` when using the `-v` option.)

Using the `-n` option calls for NFD to be used when building and running the TensorFlow benchmark app. Replace `<instance_type>` with the AWS instance type you want to use (e.g., m4.4xlarge, m4.large, p2.8xlarge etc.), or `<avx_instruction_set_name>` with the AVX instructions you want to use (either `no_avx`, `avx`, `avx2`, or `avx512`). Note that you cannot use both an instance type and AVX instructions at the same time. If you want to use a specific number of CPUs or GPUs, then use `-i` to choose an instance with the number of CPUs/GPUs you want to use.

If you're using AVX512 instructions with RHEL 7, you will need to pass in the path to the new gcc to match the gcc version you specified in `../Dockerfiles/FFTW_backend/Dockerfile.openshift_rhel7_avx512`. (The default gcc path specified in that file is `/usr/local/gcc-${GCC_VERSION}/bin/gcc-${GCC_VERSION}`.) In other words, if you specified version `9.2.0`,

```
$ sh run_me.sh -v 7 -b <blas_backend_to_use> -n -x avx512 -c '/usr/local/gcc-9.2.0/bin/gcc-9.2.0' -d <num_devices_to_use> [optional args]
```

Note that this specific RHEL 7 AVX512 image build will take a **significant** amount of time, on the order of a *few hours*. This is normal.

## Automatically creating a Node

If you wish to create a MachineSet and run the pod on a node with a specific instance type, use `../../helper_scripts/OpenShift/create_machineset.sh` to create a YAML file. Or you can create your own YAML file. The script is provided as a convenience.

Once your YAML file has been generated,

```
$ oc create -f <YAML_filename>
```

If you would like information on how to use the script,

```
$ cd ../../helper_scripts/OpenShift
$ sh create_machineset.sh -h
```

To get your AMI ID and cluster ID, either log into your [AWS console](https://aws.amazon.com/console/) and find your cluster, **or** 

```
$ aws iam list-instance-profiles --output json | grep <your_cluster_name_or_partial_cluster_name> -B 18
            "InstanceProfileId": "<instance_profile_id>", 
            "Roles": [
                {
                    "AssumeRolePolicyDocument": {
                        "Version": "2012-10-17", 
                        "Statement": [
                            {
                                "Action": "sts:AssumeRole", 
                                "Principal": {
                                    "Service": "ec2.amazonaws.com"
                                }, 
                                "Effect": "Allow", 
                                "Sid": ""
                            }
                        ]
                    }, 
                    "RoleId": "<role_id>", 
                    "CreateDate": "2019-07-18T15:57:33Z", 
                    "RoleName": "<cluster_id>-worker-role", 
                    "Path": "/", 
                    "Arn": "arn:aws:iam:<id>:role/<cluster_id>-worker-role"
                }
            ], 
            "CreateDate": "2019-07-18T15:57:33Z", 
            "InstanceProfileName": "<cluster_id>-worker-profile", 
            "Path": "/", 
            "Arn": "arn:aws:iam::<id>:instance-profile/<cluster_id>-worker-profile"

$ aws ec2 describe-instances --filters "Name=iam-instance-profile.id,Values=<instance_profile_id>" --output json | grep ImageId
                    "ImageId": "ami-<hash>", 
                    "ImageId": "ami-<hash>", 
                    "ImageId": "ami-<hash>", 
```

## Advanced CPU Options (CPU Manager)

### Installing and Enabling CPU Manager

First, install and enable CPU Manager to your cluster. To do so,

```
$ cd ../../helper_scripts/OpenShift
$ sh enable_cpumanager.sh -n <node_name> -k /path/to/cpumanager-kubeletconfig.yaml -x <avx_instruction_set>
```

or

```
$ cd ../../helper_scripts/OpenShift
$ enable_cpumanager.sh -n <node_name> -k /path/to/cpumanager-kubeletconfig.yaml -i <instance_type>
```

### Uninstalling and Disabling CPU Manager

To uninstall,

```
$ cd ../../helper_scripts/OpenShift
$ sh disable_cpumanager.sh -n <node_name> -k /path/to/cpumanager-kubeletconfig.yaml -x <avx_instruction_set>
```

or

```
$ cd ../../helper_scripts/OpenShift
$ disable_cpumanager.sh -n <node_name> -k /path/to/cpumanager-kubeletconfig.yaml -i <instance_type>
```

### Using CPU Manager

To use CPU Manager, pass in the `-p` option and choose values for `-d` and `-m`. The `-d` option ("number of devices") takes in an integer to specify the number of CPUs to use, and the `-m` option ("memory size") takes in an integer in the form of `nG`, where `n` is any integer. For example, `18G`, for 18 GB.


```
$ sh run_me.sh -v 7 -b <blas_backend_to_use> -n -x <avx_instruction_set_name> -p -d <num_cpus> -m <nG> [optional args]
```

or

```
$ sh run_me.sh -v 7 -b <blas_backend_to_use> -n -t <instance_type> -p -d <num_cpus> -m <nG> [optional args]
```

## Using the GPU

To use the GPU, pass in the `-u` option to let the script know that you're planning to use the GPU. Then provide either a URL or s3 bucket path for NCCL with the `-y` option, and provide either a URL or s3 bucket path for cuDNN with the `-z` option. Note that, due to limitations of my playbooks, NCCL and cuDNN must both be hosted in an s3 bucket in order for s3 buckets to be used.

If you are going to use s3 buckets, additional information is required. You will need to pass in the `-o` option to provide: (1.) AWS access key, (2.) AWS secret access key, (3.) AWS region, and (4.) AWS profile. (See `run_me.sh -h` for more info on the AWS arguments that are required to be passed in.)
