# secrets

This folder contains secrets used for pulling Podman/Docker images, etc.. See the sample files <filename>.example for how to create a secret. Currently, the only 'secret' you need is the secret for pulling images from registry.redhat.io.

## registry.redhat.io

To pull RHEL 8 s2i images, either through OpenShift or through Podman/Docker on your machine, you will need a YAML file that contains your registry.redhat.io secrets, as well as a plain text file that contains your registry.redhat.io Podman/Docker password. Without these "secrets" files, you will **not** be able to pull RHEL 8 s2i images. 

You can obtain your YAML file and password by visiting [the Red Hat Container Catalog](https://access.redhat.com/containers/), selecting an image name, and clicking the link on that page to sign up for a registry account.

See `redhat_io_registry.yaml.example` in this folder for a sample YAML file. Just copy-paste your registry.redhat.io Podman/Docker password in a plain text file titled `redhat_io_registry_password`. These files are consumed by specific Makefiles.
