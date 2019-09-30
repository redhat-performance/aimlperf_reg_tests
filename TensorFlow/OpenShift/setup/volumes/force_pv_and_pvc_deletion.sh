#!/bin/bash

# This script forces a PV and PVC deletion when OpenShift hangs
oc patch pv nvidia-packages-pv -p '{"metadata":{"finalizers":null}}'
oc patch pvc nvidia-packages-pvc -p '{"metadata":{"finalizers":null}}'
