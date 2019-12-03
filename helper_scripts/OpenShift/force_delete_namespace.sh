#!/bin/bash
############################################################
#  This script forces the shutdown of a namespace that is  #
#  stuck in 'Terminating' and won't actually terminate.    #
#                                                          #
#  The only input to this script is the name of the name-  #
#  space to force the shutdown of.                         #
############################################################

NAMESPACE=$1

# Get Namespace info
kubectl get namespace $NAMESPACE -o json > tmp.json

# Remove the 'kubernetes' finalizer
awk '!/"kubernetes"/' tmp.json > update.json
mv update.json tmp.json

# Start serving
kubectl proxy &

# Update namespace
curl -k -H "Content-Type: application/json" -X PUT --data-binary @tmp.json http://127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize

# Stop serving
proxy_ps=$(ps -ax | grep proxy)
proxy_id=$(echo $proxy_ps | cut -d ' ' -f 1)
kill -9 $proxy_id
