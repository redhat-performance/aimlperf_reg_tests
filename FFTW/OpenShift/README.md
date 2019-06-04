# OpenShift Files

This folder contains files used for launching the FFTW multidimensional cosine app in OpenShift on AWS. To run, first make sure you've set up an OpenShift AWS instance and exposed your image registry (Docker, CRI-O, etc.). Then run:

```
$ sh run_me.sh [RHEL-version] [nfd] [true/false] [true/false]
```

e.g.,

```
$ sh run_me.sh 7
```

The above command will load the templates from the `templates` folder into your OpenShift AWS instance, create a build image special for the OpenBLAS code in this repo, and run the gemm app.

By default, your OpenShift image will be named `fftw-rhel7` and will be saved to your exposed OpenShift image registry. (NOTE: You don't need to tell the `run_me.sh` script the link to your registry since the script automatically determines the link for you. However, if you have *multiple* registries for whatever reason, you may want to edit which registry to use. So, edit the `REGISTRY` variable.)

You can run `run_me.sh` multiple times if you want. It is safe to do so, as it cleans up the environment every time you want to start a new build.

Note that if you want to build using [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery/) make sure you have it installed prior to running the following command:

```
$ sh run_me.sh 7 nfd <instance-type>
```

This command calls for NFD to be used when building and running the FFTW benchmark app. Replace `<instance-type>` with the AWS instance type you want to use (e.g., m4.4xlarge, m4.large, etc.).

If you wish to create a MachineSet and run the pod on a node with a specific instance type, use `scripts/create_machineset.sh`.
