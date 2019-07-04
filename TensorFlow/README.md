# TensorFlow Regression Tests

The contents of this folder are currently in progress, but as of now, there are two playbooks for building and installing a custom TensorFlow and its required packages. The custom TensorFlow utilizes a custom NumPy built with either FFTW or OpenBLAS, which thus means the playbooks also build a custom NumPy.

## Building TensorFlow with Ansible

To build TensoFlow with a custom FFTW or custom OpenBLAS, first install Ansible and build a custom FFTW or custom OpenBLAS (see `../FFTW` and `../OpenBLAS`). Next, install the required packages for building TensorFlow:

```
$ cd playbooks/package_installation
$ ansible-playbook -i hosts play.yaml
```

Now that the necessary packages have been installed, it's time to build TensorFlow. 

By default, the custom NumPy that TensorFlow uses will be built with FFTW. If you would like to use FFTW as a backend, then run:

```
$ cd ../TensorFlow_installation
$ ansible-playbook -i hosts play.yaml
```

If you would like to use OpenBLAS as a backend instead, then run:

```
$ cd ../TensorFlow_installation
$ ansible-playbook -i hosts play.yaml --extra-vars="{use_fftw: 'no', use_openblas: 'yes'}"
```

## TODO

Ultimately, the goal here is to run TensorFlow benchmarks/regression-tests in OpenShift on AWS. OpenShift files will be added shortly.
