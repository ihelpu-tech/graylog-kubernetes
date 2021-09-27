#!/bin/bash
# Licensed under the GNU General Public License (GPLv3) https://github.com/ihelpu-tech/graylog-kubernetes/blob/main/LICENSE

######### Part 1: Create secrets #########

echo "This script will create a kubernetes secret for the MongoDB user password and then create a replica set."
echo

SECRETPATH=/tmp/create-mongo-secret.yaml
REPLICAPATH=/tmp/create-mongo-replicaset.yaml

unset KUBEALIAS
echo "Set kubectl alias.\
\
Ex: kubectl, k, microk8s kubectl"
read -p "Set alias (kubectl): " KUBEALIAS
KUBEALIAS=${KUBEALIAS:-kubectl}
echo

unset SECRETNAME
read -p "Set secret name (mongodb-graylog-secret): " SECRETNAME
SECRETNAME=${SECRETNAME:-mongodb-graylog-secret}
echo

unset PASSWORD
unset PASSWORD2
echo "Passwords are encoded to Base64. \
\
Please note that this is NOT encyption."

while true; do
	read -s -p "Create MongoDB secret password: " PASSWORD
	echo
	read -s -p "Confirm password: " PASSWORD2
	echo
	[ "$PASSWORD" = "$PASSWORD2" ] && break || echo "Please try again"
	# [ "$password" = "$password2" ] && break || echo "Please try again"
done

PASSWORD=$(echo "$PASSWORD" | openssl enc -base64)
echo

unset NAMESPACE
read -p "Set namespace (graylog): " NAMESPACE
NAMESPACE=${NAMESPACE:-graylog}
echo

echo "Creating yaml file at $SECRETPATH"
cat <<EOF > $SECRETPATH
---
apiVersion: v1
kind: Secret
metadata:
  name: $SECRETNAME
  namespace: $NAMESPACE
type: Opaque
stringData:
# Secret is base64 encoded
#Note: This is not encryption
  password: $PASSWORD
EOF

#Apply secret
echo "$KUBEALIAS apply -f $SECRETPATH"  | /bin/bash

#Test for secret
echo "$KUBEALIAS get secret --namespace $NAMESPACE $SECRETNAME" | /bin/bash

unset PASSWORD
unset PASSWORD2



######### Part 2: Create Replica Set #########
echo
echo
echo "Deploying replicaset..."
echo

unset REPLICANAME
read -p "Set replica set name (graylog-mongodb): " REPLICANAME
REPLICANAME=${REPLICANAME:-graylog-mongodb}
echo

unset NUMBEROFMEMBERS
read -p "Set number of replica set members (1): " NUMBEROFMEMBERS
NUMBEROFMEMBERS=${NUMBEROFMEMBERS:-1}
echo

unset CLUSTERUSERNAME
read -p "Set mongodb admin username (administrator): " CLUSTERUSERNAME
CLUSTERUSERNAME=${CLUSTERUSERNAME:-administrator}
echo

unset CLUSTERVERSION
read -p "Set mongodb version (4.4.9): " CLUSTERVERSION
CLUSTERVERSION=${CLUSTERVERSION:-4.4.9}
echo

cat <<EOF > $REPLICAPATH
---
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: $REPLICANAME
  namespace: $NAMESPACE
  labels:
    app: graylog
spec:
  members: $NUMBEROFMEMBERS
  type: ReplicaSet
  version: "$CLUSTERVERSION"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: $CLUSTERUSERNAME
      db: admin
      passwordSecretRef: # a reference to the secret that will be used to generate the user's password
        name: $SECRETNAME
      roles:
        - name: clusterAdmin
          db: admin
        - name: userAdminAnyDatabase
          db: admin
      scramCredentialsSecretName: my-scram
  additionalMongodConfig:
    storage.wiredTiger.engineConfig.journalCompressor: zlib
EOF

echo "$KUBEALIAS apply -f $REPLICAPATH"  | /bin/bash

echo
echo "Script complete..."
echo "Run: 'kubectl get mongodbcommunity --namespace $NAMESPACE' to view progress."
echo