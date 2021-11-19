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

# Declare function to print out script usage
function usage() {
    cat <<USAGE

    Usage: $0 [-n namespace]

    Options:
        -n, --namespace:            Set namespace
        
USAGE
    exit 1
}

# Set flags
while [ "$1" != "" ]; do
	case $1 in
	-n | --namespace)
		shift
		NAMESPACE=$1
		;;
	
    *)
		printf "\033[1;31mError: Invalid option!\033[0m\n"
		usage
		exit 1
		;;
	esac
	shift
done

echo "Step 1: Start a local container to copy the original cacerts file"

#Modified to let the user choose which version of the Graylog Docker image they want to use.
#Defaults to Graylog 4.1 with JRE 11.
unset DOCKER_IMAGE
read -p "Set Graylog Docker image (graylog/graylog:4.2-jre11): " DOCKER_IMAGE
DOCKER_IMAGE=${DOCKER_IMAGE:-graylog/graylog:4.2-jre11}
echo "Docker Image: $DOCKER_IMAGE"

unset JAVAVERSION
read -p "Set Java version (11): " JAVAVERSION
JAVAVERSION=${JAVAVERSION:-11}
echo "Java Version: $JAVAVERSION"

echo "Some systems require root access to create docker images."
echo "Please enter 'sudo' password: "
ID=$(sudo docker create $DOCKER_IMAGE)
echo $ID
sudo docker cp $ID:/usr/local/openjdk-$JAVAVERSION/lib/security/cacerts - | tar xvf - > cacerts
chmod 755 cacerts
sudo docker rm -v $ID

# Step 1 test stop
# exit

echo "Step 2: Extract Elasticsearch HTTPS Certificate"

# Let user select namespace
# unset NAMESPACE
if [ "$NAMESPACE" = "" ]; then
	read -p "Set namespace (graylog): " NAMESPACE
	NAMESPACE=${NAMESPACE:-graylog}
	echo
fi

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
sudo docker run -it --rm -v $(pwd):$(pwd) openjdk keytool -importcert -noprompt -keystore $(pwd)/cacerts -storepass changeit -alias elasticsearch-cert -file $(pwd)/es.pem

echo "Step 4: Create K8s ConfigMap from keystore file"
# kubectl create configmap --namespace $NAMESPACE graylog-keystore --from-file=cacerts
# echo $(kubectl get configmap --namespace $NAMESPACE)
KEYSTOREPRESENT=$(kubectl get configmap --namespace $NAMESPACE | grep graylog-keystore | awk '{print $1}')
if [ -n "$KEYSTOREPRESENT" ]
    then
        echo "Keystore is already present"
        
        while true; do
            read -p "Do you want to regenerate the keystore configmap? Y/n: " yn
            case $yn in
                [Yy]* ) 
                    echo "Regenerating config";
                    kubectl delete configmap --namespace $NAMESPACE graylog-keystore;
                    kubectl create configmap --namespace $NAMESPACE graylog-keystore --from-file=cacerts;
                    break;;

                [Nn]* ) 
                    echo "Skipping...";
                    break;;

                * ) 
                    echo "Please answer yes or no.";;
            esac
        done
    
    else
        echo "Keystore is not present. Creating one now..."
        kubectl create configmap --namespace $NAMESPACE graylog-keystore --from-file=cacerts
fi
kubectl get configmap --namespace $NAMESPACE

echo "Step 5: Cleanup"
rm -f es.pem cacerts