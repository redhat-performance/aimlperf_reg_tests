# Setup

This folder contains files for setting up various things in OpenShift related to the TensorFlow parent folder.

Currently, there are two folders:

  1. `images`
  2. `volumes`

The `images` folder contains files for setting up OpenShift to pull images from registry.redhat.io, while the `volumes` folder contains files for setting up OpenShift to create an EBS for storing NVIDIA related files, such as the cuDNN and NCCL tarballs, such that they can be used for building TensorFlow.

## Images


### registry.redhat.io Images

Run `add_registry_secret.sh` to add your redhat.io registry secret to OpenShift. Make sure you have a registry secret already added to the top level `secrets` folder in this repository. See the main `../OpenShift/README.md` file for more information.

### Custom CUDA Images (from ../../Dockerfiles/custom)

To create a custom CUDA image defined by one of the Dockerfiles in the `TensorFlow/Dockerfiles/custom` folder, you will need to have added your registry.redhat.io secret to Podman/Docker and do the following:

1a. Create `.repo` files in the `../../../repos` folder for `cuda.repo` and `rhel8-Latest.repo`

1b. Additionally, create a `.repo` file in the `../../../repos` folder for `rhel8-Appstream-Latest.repo` if using a Dockerfile which installs CUDA toolkit

2. Log into the redhat.io registry using your credentials. See https://access.redhat.com/RegistryAuthentication for more info.

3. Use the `podman` or `docker` CLI to build the custom image, making sure to tag the image with the OpenShift image registry route

4. Expose the OpenShift image registry

5. Log into the OpenShift `podman`/`docker` registry

6. Push the image to the OpenShift registry

7. Setup registry secret so that the custom image can be pulled into an OpenShift build

The image must be built on your own machine, and the next subsections describe the above steps in greater detail.

#### 1. Create .repo Files for CUDA and RHEL 8

Follow the directions described in `../../../repos/README.md` for creating the necessary `.repo` files.

#### 2. Log into the redhat.io Registry

Enter your registry.redhat.io credentials using:

```
podman login -u <your-username> -p <-your-token> registry.redhat.io
```

#### 3. Use the Podman or Docker CLI to Build the Custom Image

To build the image after you've logged into the registry:

```
$ cd ../../../
$ podman build -f TensorFlow/Dockerfiles/custom/Dockerfile.rhel8_cuda10.1 . --tag ${HOST}/openshift-image-registry/cuda_rhel8
```

#### 4. Exposing the OpenShift Image Registry

In OpenShift 4.1 (OCP 4.1):

```
$ oc project openshift-image-registry
$ oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

(Source: https://docs.openshift.com/container-platform/4.1/registry/securing-exposing-registry.html)

#### 5. Log into the OpenShift Podman/Docker Registry

```
$ oc project openshift-image-registry
$ HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
$ TOKEN=$(oc serviceaccounts get-token 'builder')
$ podman login -u default -p ${TOKEN} --tls-verify=false ${HOST}
```

Simply replace `podman` with `docker` if you're going to use Docker.

#### 6. Push the Image to the OpenShift Registry

Note: this step may take a while...

```
$ podman push ${HOST}/openshift-image-registry/cuda_rhel8 --tls-verify=false
```

To confirm the push was successful, you should run `oc get is` and see an output such as:

```
$ oc get is
NAME          IMAGE REPOSITORY                                                                            TAGS     UPDATED
cuda_rhel8    default-route-openshift-image-registry.<cluster_url>/openshift-image-registry/cuda_rhel8    latest   8 minutes ago
```

#### 7. Set up Registry Secret

Set up the registry secret using the same value of `${TOKEN}` as defined in step 3.

```
$ oc secrets new-dockercfg openshft-image-registry-pull-secret \
                           --docker-server=image-registry.openshift-image-registry.svc:5000 \
                           --docker-username=default \
                           --docker-password=${TOKEN} \
                           --docker-email=null
```

## Volumes

Run `create_ebs_volume.sh` to create an EBS volume. Call `sh create_ebs_volumes.sh -h` for help on how to use the script. 

Once the EBS volume has been created, create a dummy pod that can be used to save data to the EBS volume by using the `create_temp_pod.sh` script. It only takes in one argument -- the **volume ID** generated from the `create_ebs_volumes.sh` script.
