#!/bin/bash

usage() {
    echo "This script generates a config file for creating a MachineSet on your AWS OpenShift cluster."
    echo ""
    echo "Usage: $0 [-c cluster_id] [-r role] [-k region] [-z availability_zone] [-i instance_type]"
    echo "  REQUIRED:"
    echo "  -c  ID of your Cluster"
    echo "  -r  Cluster role. Choose from: {worker,infra,master}"
    echo "  -a  AMI ID"
    echo "  -k  Region. (Use the region you configured AWS with)"
    echo "  -z  Availability zone. (Use 'aws ec2 describe-availability-zones' to list availability zones)"
    echo "  -i  Instance type. (e.g., m4.large, m4.4xlarge, etc.)"
    echo ""
    echo "  OPTIONAL:"
    echo "  -f  The name which will be used for the template. Default name: <cluster_id>-machineset-<instance_type>-config.yaml"
    exit
}

options=":h:c:r:a:k:z:i:"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      c)
          CLUSTER_ID=${OPTARG}
          ;;
      r)
          ROLE=${OPTARG}
          ;;
      a)
          AMI_ID=${OPTARG}
          ;;
      k)
          REGION=${OPTARG}
          ;;
      z)
          AVAILABILITY_ZONE=${OPTARG}
          ;;
      i)
          INSTANCE_TYPE=${OPTARG}
          ;;
      f)
          FILENAME=${OPTARG}
          ;;
      *)
          usage
          ;;
    esac
done
shift $((OPTIND-1))

# Check if -c was passed
if [[ -z ${CLUSTER_ID} ]]; then
    echo "Please enter a cluster ID by passing in a value for -c. To find your cluster ID, execute 'aws iam list-instance-profiles'"
    exit 1
fi

# Check if cluster exists
describe_addresses=$(aws ec2 describe-addresses | grep ${CLUSTER_ID})
if [[ -z ${describe_addresses} ]]; then
    echo "Cluster ID '${CLUSTER_ID}' does not exist."
    exit 1
fi

# Check validity of role
if [[ -z ${ROLE} ]]; then
    echo "Please enter a role by passing in a value for -r. Choose from: {worker,infra,master}"
    exit 1
elif [ ${ROLE} != "master" ] && [ ${ROLE} != "infra" ] && [ ${ROLE} != "worker" ]; then
    echo "Invalid role option. Choose from: {worker,infra,master}"
    exit 1
fi

# Check if -k was passed
if [[ -z ${REGION} ]]; then
    echo "Please enter a region by passing in a value for -k."
    exit 1
fi

# Check if -z was passed
if [[ -z ${AVAILABILITY_ZONE} ]]; then
    echo "Please enter an availability zone by passing in an argument for -z."
    exit 1
fi

# Check if availability zone is valid
availability_zone_options=($(aws ec2 describe-availability-zones | grep "ZoneName" | cut -d':' -f 2 | cut -d'"' -f 2))
valid_zone=0
for zone in "${availability_zone_options[@]}"; do
    if [[ ${AVAILABILITY_ZONE} == $zone ]]; then
        valid_zone=1
        break
    fi
done
if [[ ${valid_zone} == 0 ]]; then
    echo "Invalid availability zone ${AVAILABILITY_ZONE}. Please use 'aws ec2 describe-availability-zones' to see availability zone options."
fi

# Check if -i was passed
if [[ -z ${INSTANCE_TYPE} ]]; then
    echo "Please enter an instance type by passing in an argument for -i."
    exit 1
fi

# Check if -a was passed
if [[ -z ${AMI_ID} ]]; then
    echo "Please enter your AMI ID by passing in an argument for -a."
    exit 1
elif [[ ${AMI_ID} != "ami-"* ]]; then
    echo "AMI ID must start with \"ami-\". ${AMI_ID} is not valid."
    exit 1
fi

# Set filename
if [[ -z ${FILENAME} ]]; then
    FILENAME="${CLUSTER_ID}-machineset-${INSTANCE_TYPE}-config.yaml"
fi

echo "apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
  name: ${CLUSTER_ID}-${ROLE}-${AVAILABILITY_ZONE}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
      machine.openshift.io/cluster-api-machine-role: ${ROLE}
      machine.openshift.io/cluster-api-machine-type: ${ROLE}
      machine.openshift.io/cluster-api-machineset: ${CLUSTER_ID}-${ROLE}-${AVAILABILITY_ZONE}
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
        machine.openshift.io/cluster-api-machine-role: ${ROLE}
        machine.openshift.io/cluster-api-machine-type: ${ROLE}
        machine.openshift.io/cluster-api-machineset: ${CLUSTER_ID}-${ROLE}-${AVAILABILITY_ZONE}
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/<role>: ""
      providerSpec:
        value:
          ami:
            id: ${AMI_ID}
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
            - ebs:
                iops: 0
                volumeSize: 120
                volumeType: gp2
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: ${CLUSTER_ID}-worker-profile
          instanceType: ${INSTANCE_TYPE}
          kind: AWSMachineProviderConfig
          placement:
            availabilityZone: ${AVAILABILITY_ZONE}
            region: ${REGION}
          securityGroups:
            - filters:
                - name: tag:Name
                  values:
                    - ${CLUSTER_ID}-worker-sg
          subnet:
            filters:
              - name: tag:Name
                values:
                  - ${CLUSTER_ID}-private-${AVAILABILITY_ZONE}
          tags:
            - name: kubernetes.io/cluster/${CLUSTER_ID}
              value: owned
          userDataSecret:
            name: worker-user-data
" > ${FILENAME}
