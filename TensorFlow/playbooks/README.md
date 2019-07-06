# TensorFlow Playbooks

This folder contains three playbooks for building, installing, and running TensorFlow:

  1. `package_installation`
  2. `TensorFlow_installation`
  3. `TensorFlow_benchmarks`

The first playbook installs the required packages for building TensorFlow. It requires super user. The second playbook installs TensorFlow itself, but it does not use super user. Instead, it installs the package locally to `${HOME}/.local/lib/python3.6/site-packages`. And finally, the last playbook downloads the benchmarks and runs them.

## Package Installation

To install required packages, first make sure you have write permissions to `/usr/local/lib` and `/usr/lib64`. Once you're ready, you can install the required packages on a RHEL 7 machine via:

```
$ cd package_installation
$ ansible-playbook -i hosts play.yaml
```

Alternatively, for a RHEL 8 machine,

```
$ cd package_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
```

## TensorFlow Installation

To install TensorFlow on a RHEL 7 machine,

```
$ cd TensorFlow_installation
$ ansible-playbook -i hosts play.yaml
```

For a RHEL 8 machine,

```
$ cd TensorFlow_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{rhel_version: 8}"
```

## TensorFlow Benchmarks

To run the Resnet50 TensorFlow benchmarks on a RHEL 7 *or* RHEL 8 machine,

```
$ cd TensorFlow_benchmarks
$ ansible-playbook -i hosts play.yaml
```

Alternatively, you can use a different benchmark by passing in `--extra-vars="{model: <model-name>}"`. Options for `<model-name>` are: `resnet50`, `inception3`, `vgg16`, and `alexnet`.

You can also run the benchmarks on a GPU if you'd prefer the GPU over the CPU. To do so, pass in `--extra-vars="{device: gpu}"

Benchmark results are saved to a file named `[model]-[device]-benchmark-[yyyy]-[mm]-[dd]-[hh]:[mm]:[ss].log` under `${HOME}/tensorflow_benchmarks/tf_cnn_benchmraks`.
