#!/bin/bash

usage() {
    echo "This script creates an EBS volume on AWS."
    echo ""
    echo "Usage: $0 [-t volume_type] [-s size] [-z availability_zone]"
    echo "  REQUIRED:"
    echo "  -t  Volume type. Choose from: {standard, io1, gp2, sc1, st1}"
    echo "  -s  Volume size, in GiBs."
    echo "  -z  Availability zone. (e.g., 'us-east-1b' or 'us-west-2a' etc. etc.)"
    echo "  -n  Name of the volume."
    exit 
}

options=":ht:s:z:n:"
while getopts "$options" x
do
    case "$x" in
      h)
          usage
          ;;
      t)
          VOLUME_TYPE=${OPTARG}
          ;;
      s)
          SIZE=${OPTARG}
          ;;
      z)
          AVAILABILITY_ZONE=${OPTARG}
          ;;
      n)
          VOLUME_NAME=${OPTARG}
          ;;
      *)
          usage
          ;;
  esac
done
shift $((OPTIND-1))

if [[ -z $VOLUME_TYPE ]]; then
    echo "ERROR. Please provide a volume type using the -t option. Choose from: {standard, io1, gp2, sc1, st1}"
    exit 1
elif [[ -z $SIZE ]]; then
    echo "ERROR. Please provide a volume size using the -s option. Use the -h option for more info."
    exit 1
elif [[ -z $AVAILABILITY_ZONE ]]; then
    echo "ERROR. Please provide an availability zone with the -z option. Use the -h option for more info."
    exit 1
elif [[ -z $VOLUME_NAME ]]; then
    echo "ERROR. Please provide a name for the volume with the -n option. Use the -h option for more info."
fi

aws ec2 create-volume --volume-type $VOLUME_TYPE \
                      --size $SIZE \
                      --availability-zone $AVAILABILITY_ZONE \
                      --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=${VOLUME_NAME}}]"
