# OpenShift Helper Scripts

This folder contains scripts for executing various commands on an existing OpenShift cluster.

Current scripts:

  - `create_machineset.sh` - Creates a MachineSet YAML file for launching a new node of a specific size on an existing OpenShift cluster
  - `disable_cpumanager.sh` - Disables CPU Manager on an existing OpenShift cluster
  - `enable_cpumanager.sh` - Enables CPU Manager on an existing OpenShift cluster
  - `force_delete_namespace` - Forcefully deletes a hanging namespace (e.g., if OpenShift SRO is stuck in 'Terminating' and won't actually terminate)
  - `gpu_setup.sh` - Prepares an existing OpenShift cluster for using GPUs
  - `nfd_setup.sh` - Deploys the Node Feature Discovery (NFD) Operator on an existing OpenShift cluster

## Usage

The following descriptions explain how to use each script

### create\_machineset.sh

For help on how to use the script, run:

```
$ sh create_machineset.sh -h
```

You will need:

  1. Cluster ID - The ID of your cluster 
  2. AMI ID - The Amazon Machine Image ID
  3. Cluster Role - One of: {worker, infra, master}
  4. Region - The region you configured your `aws` CLI with. For example, `us-west-2` or `us-east-1`.
  5. Availability Zone - The availability zone where the node will be placed. See the following page for availability zones: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html
  6. Instance type - The AWS instance type. See the following page for instance types and prices: https://aws.amazon.com/ec2/instance-types/

You can find your AMI and Cluster IDs from the "EC2" tab in the AWS Console. Or, you can use the `aws` CLI to find this information.

### disable\_cpumanager.sh and enable\_cpumanager.sh

For help on how to run these scripts,

```
$ disable_cpumanager.sh -h
$ enable_cpumanager.sh -h
```

### gpu\_setup.sh

Only run this script if you plan to deploy GPU apps on OpenShift. Also, before you run this script, you should run `nfd_setup.sh` via:

```
$ sh nfd_setup.sh
```

Then run:

```
$ sh gpu_setup.sh <OCP-version>
```

e.g.,

```
$ sh gpu_setup.sh 4.2
```

### nfd\_setup.sh

Run this script if you would like to deploy the NFD Operator on OpenShift. To run,

```
$ sh nfd_setup.sh <OCP-version>
```

e.g.,

```
$ sh nfd_setup.sh 4.2
```

### force\_delete\_namespace.sh

Run this script to force delete a namespace. For example,

```
$ sh force_delete_namespace.sh openshift-sro
```
