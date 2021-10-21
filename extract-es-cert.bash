#!/bin/bash
# The following script will help with getting the Elasticsearch HTTPS certificate trusted by the Graylog instance.
# The script was modified from a user from Github/Stackoverflow whose username escapes my memory. Thanks for your contribution anon.

# Test for docker
if ! command -v docker &> /dev/null
then
    printf "\033[1;31mError: docker could not be found\033[0m\n"
    echo "Install docker: https://docs.docker.com/get-docker/"
    exit
fi

echo "Step 1: Start a local container to copy the original cacerts file"

#Modified to let the user choose which version of the Graylog Docker image they want to use.
#Defaults to Graylog 4.1 with JRE 11.
unset DOCKER_IMAGE
read -p "Set Graylog Docker image (graylog/graylog:4.1-jre11): " DOCKER_IMAGE
DOCKER_IMAGE=${DOCKER_IMAGE:-graylog/graylog:4.1-jre11}
echo "Docker Image: $DOCKER_IMAGE"

unset JAVAVERSION
read -p "Set Java version (11): " JAVAVERSION
JAVAVERSION=${JAVAVERSION:-11}
echo "Java Version: $JAVAVERSION"

ID=$(docker create $DOCKER_IMAGE)
echo $ID
docker cp $ID:/usr/local/openjdk-$JAVAVERSION/lib/security/cacerts - | tar xvf - > cacerts
chmod 755 cacerts
docker rm -v $ID

# Step 1 test stop
# exit

echo "Step 2: Extract Elasticsearch HTTPS Certificate"

### Depricated kubealias option for simplicity. 
# unset KUBEALIAS
# echo "Set kubectl alias.\
# \
# Ex: kubectl, k, microk8s kubectl"
# read -p "Set alias (kubectl): " KUBEALIAS
# KUBEALIAS=${KUBEALIAS:-kubectl}
# echo

# Let user select namespace
unset NAMESPACE
read -p "Set namespace (graylog): " NAMESPACE
NAMESPACE=${NAMESPACE:-graylog}
echo

# Automatically find the http secret
unset SECRETNAME
SECRETNAME=$((kubectl get secrets -n $NAMESPACE | grep es-http-certs-public) | awk '{print $1}')
echo "Found secret: $SECRETNAME"

while true; do
    read -p "Use this secret: $SECRETNAME? Y/n: " yn
    case $yn in
        [Yy]* ) echo "Using found secret"; break;;
        [Nn]* ) read -p "Specify secret name: " SECRETNAME; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

kubectl get secret -n $NAMESPACE $SECRETNAME -o go-template='{{index .data "tls.crt" | base64decode }}' > es.pem

# Step 2 test stop
# exit

echo "Step 3: Import Elasticsearch HTTPS Certificate into Keystore"
docker run -it --rm -v $(pwd):$(pwd) openjdk keytool -importcert -noprompt -keystore $(pwd)/cacerts -storepass changeit -alias elasticsearch-cert -file $(pwd)/es.pem

echo "Step 4: Create K8s ConfigMap from keystore file"
kubectl create configmap --namespace $NAMESPACE graylog-keystore --from-file=cacerts
# echo $(kubectl get configmap --namespace $NAMESPACE)

echo "Step 5: Cleanup"
rm -f es.pem cacerts