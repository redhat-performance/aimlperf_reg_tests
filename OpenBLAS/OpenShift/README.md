# OpenShift Files

This folder contains files used for launching the OpenBLAS "gemm" app in OpenShift on AWS. To run, first make sure you've set up an OpenShift AWS instance and exposed your image registry (Docker, CRI-O, etc.). Then run:

```
$ sh run_me.sh -v [RHEL-version]
```

e.g.,

```
$ sh run_me.sh -v 7
```

The above command will load the RHEL 7 templates from the `standard/templates` folder into your OpenShift AWS instance, create a build image special for the OpenBLAS code in this repo, and run the gemm app.

By default, your OpenShift image will be named `openblas-rhel7` and will be saved to your exposed OpenShift image registry. (NOTE: You don't need to tell the `run_me.sh` script the link to your registry since the script automatically determines the link for you. However, if you have *multiple* registries for whatever reason, you may want to edit which registry to use. So, edit the `REGISTRY` variable.)

You can run `run_me.sh` multiple times if you want. It is safe to do so, as it cleans up the environment every time you want to start a new build.

You can also use NFD (Node Feature Discovery) via the `-n` option. The `-n` option must be combined with either `-i` (for instance type) or `-x` (for AVX instructions).
