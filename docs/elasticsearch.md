# Connecting Elasticsearch

*WIP*

This will be a guide on how to connect graylog to elasticsearch deployed via ECK. This is also a code dump area for important commands. 

[Installation Guide][Install]

### Find Elasticsearch HTTP service
Get the name of the es-http service.
```
kubectl get services --namespace graylog | grep es-http
```

### Install Testing Utilities
Install [Graylog Utilities][graylogutils] into your namespace.
```
kubectl apply -f yaml/graylog-testutils.yaml --namespace graylog
```

### Get Elastic Password
Find the correct secret:
```
kubectl get secrets --namespace graylog | grep es-elastic-user
```

Decode the secret:
```
kubectl get secret --namespace graylog graylog-elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode }}'
```

### Test to see if Elasticsearch responds to request
```
kubectl exec --namespace graylog -it pod/graylogutils -- curl -u "elastic:<password>" -k "https://graylog-elasticsearch-es-http:9200"
```
We should get a response back in json-like format with the details of the cluster:

```
$ kubectl exec --namespace graylog -it pod/graylogutils -- curl -u "elastic:SQLXw0833x008Oe2aMwd1m1N" -k "https://graylog-elasticsearch-es-http:9200"

{
  "name" : "graylog-elasticsearch-es-default-2",
  "cluster_name" : "graylog-elasticsearch",
  "cluster_uuid" : "5-wj5_WvQmipKxUyTbD9FA",
  "version" : {
    "number" : "7.10.2",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "747e1cc71def077253878a59143c1f785afa92b9",
    "build_date" : "2021-01-13T00:42:12.435326Z",
    "build_snapshot" : false,
    "lucene_version" : "8.7.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```




## Code:
The following is some code to assist with importing certs into Java.
```
openssl s_client -showcerts -connect graylog-elasticsearch-es-http:9200 -servername graylog-elasticsearch-es-http  </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > graylog-elasticsearch-es-http.pem

openssl x509 -outform der -in graylog-elasticsearch-es-http.pem -out graylog-elasticsearch-es-http.der

keytool -import -alias your-alias -keystore cacerts -file certificate.der
```

The following is a script I got from a StackOverflow user. Their username escapes my memory.
``` 
#!/bin/bash

DOCKER_IMAGE="graylog/graylog:3.2"

echo "Step 1: Start a local container to copy the original cacerts file"
ID=$(docker create $DOCKER_IMAGE)
docker cp $ID:/usr/local/openjdk-8/lib/security/cacerts - | tar xvf - > cacerts
chmod 755 cacerts
docker rm -v $ID

echo "Step 2: Extract Elasticsearch HTTPS Certificate"
kubectl get secret -n elasticsearch graylog-es-cluster-es-http-certs-public -o go-template='{{index .data "tls.crt" | base64decode }}' > es.pem

echo "Step 3: Import Elasticsearch HTTPS Certificate into Keystore"
docker run -it --rm -v $(pwd):$(pwd) openjdk keytool -importcert -noprompt -keystore $(pwd)/cacerts -storepass changeit -alias elasticsearch-cert -file $(pwd)/es.pem

echo "Step 4: Create K8s ConfigMap from keystore file"
kubectl create configmap --namespace graylog graylog-keystore --from-file=cacerts

echo "Step 5: Cleanup"
rm -f es.pem cacerts
```


[Install]: install.md

[graylogutils]: ../yaml/graylog-testutils.yaml