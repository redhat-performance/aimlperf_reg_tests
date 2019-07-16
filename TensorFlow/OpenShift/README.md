# OpenShift Files

This folder contains files used for launching the [official TensorFlow High-Performance CNN benchmarks](https://github.com/tensorflow/benchmarks/tree/master/scripts/tf_cnn_benchmarks) as an app in OpenShift on AWS. To run, first make sure you've set up an OpenShift AWS instance and exposed your image registry (Docker, CRI-O, etc.). The instance can be either a CPU or GPU type. Once your OpenShift AWS is ready, run:

```
$ sh run_me.sh -v <rhel_version>
```

e.g.,

```
$ sh run_me.sh -v 7
```

The above command will load the templates from the `templates` folder into a random AWS instance, create a build image special for the TensorFlow benchmarks, then run the benchmarks.

By default, your OpenShift image will be named `tensorflow-rhel7` and will be saved to your exposed OpenShift image registry. (NOTE: You don't need to tell the `run_me.sh` script the link to your registry since the script automatically determines the link for you. However, if you have *multiple* registries for whatever reason, you may want to edit which registry to use. So, edit the `REGISTRY` variable.)

You can run `run_me.sh` multiple times if you want. It is safe to do so, as it cleans up the environment every time you want to start a new build.

Note that if you want to build using [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery/) and run on a specific node, make sure you have it installed prior to running one of the the following commands:

```
$ sh run_me.sh -v 7 -n -i <instance-type> [optional args]
```
or

```
$ sh run_me.sh -v 7 -n -x <avx-instruction-set-name> [optional args]
```

Using the `-n` option calls for NFD to be used when building and running the TensorFlow benchmark app. Replace `<instance-type>` with the AWS instance type you want to use (e.g., m4.4xlarge, m4.large, etc.), or `<avx-instruction-set-name>` with the AVX instructions you want to use (either `no_avx`, `avx`, `avx2`, or `avx512`). Note that you cannot use both an instance type and AVX instructions at the same time.

If you wish to create a MachineSet and run the pod on a node with a specific instance type, use `scripts/create_machineset.sh`. Or you can create your own. The script is provided as a convenience.

If you'd like, there is now an option to use the CPU Manager to set number of CPUs and memory size to use when executing the benchmarks. To use CPU Manager, pass in the `-p` option and choose values for `-c` and `-m`. The `-c` option takes in an integer, and the `-m` option takes in an integer in the form of `nG`, where `n` is any integer. For example, `18G`, for 18 GB.
