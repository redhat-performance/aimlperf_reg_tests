# TensorFlow Regression Tests

The contents of this folder are currently in progress, but as of now, there are two playbooks for building and installing a custom TensorFlow and its required packages. The custom TensorFlow utilizes a custom NumPy built with either FFTW or OpenBLAS, which thus means the playbooks also build a custom NumPy.

## Building TensorFlow with Ansible

View `playbooks/README.md` for information on how to build TensorFlow with Ansible

## Running TensorFlow CNN High-Performance Benchmarks

View `playbooks/README.md` to see how to run the benchmarks. Note that in order to run these benchmarks, though, you are required to have installed TensorFlow locally to `${HOME}/.local/lib/python3.6/site-packages`. Using the `playbooks/TensorFlow_installation` playbook will install TensorFlow to that directory for you. Alternatively, if you just want to test the benchmarks without having to build TensorFlow from source, 

```
$ pip3 install --user tensorflow
```
