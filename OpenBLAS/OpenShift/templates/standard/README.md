# Template Files

The contents of this folder are intended to be used for launching the OpenBLAS benchmark app in OpenShift on AWS, but you may also use it for a non-AWS OpenShift instance.

## Files

### openblas-buildconfig.yaml

This yaml file contains a template used for creating a BuildConfig and ImageStream. It has parameters `IMAGESTREAM_NAME`, which will be the name of the OpenBLAS image when it is saved to your OpenShift instance, and `REGISTRY`, which is the name fo your Docker/CRI-O registry.

### openblas-build-job.yaml

This yaml file contains a template used for calling S2I. It has two parameters: (1.) `IMAGESTREAM_NAME`, (2.) `REGISTRY`, (3.) `APP_NAME`, and (4.) `NAMESPACE`. The first two parameters in this template are the same as the two parameters in the previous template. The third parameter is the name of your app (e.g., `openblas-gemm-s2i-app`) and the fourth parameter is the OpenShift namespace/project you're working on (see `oc project`).
