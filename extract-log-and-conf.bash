#!/bin/bash
echo "Extracting server.conf and graylog-server.log..."
PODNAME=$(kubectl get pods -n graylog | grep graylog-deployment | awk '{print$1}')
kubectl exec -n graylog -it $PODNAME -- cat /usr/share/graylog/log/graylog-server.log>graylog-server.log
echo "Extracted Log"
kubectl exec -n graylog -it $PODNAME -- cat /etc/graylog/server/server.conf>server.conf
echo "Extracted Config"