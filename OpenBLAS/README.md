# OpenBLAS Regression Tests

Currently, I only have code for running OpenBLAS sgemm and dgemm. Dockerfiles for building OpenBLAS with `rpmbuild` will be added soon.

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
