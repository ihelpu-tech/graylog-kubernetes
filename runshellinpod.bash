#!/bin/bash
echo "Getting shell inside pod..."
PODNAME=$(kubectl get pods -n graylog | awk '/graylog\-master/ {print $1}')
kubectl exec -n graylog -it $PODNAME -- bash