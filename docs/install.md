# Installation Guide for running Graylog on Kubernetes
Step-by-step guide on how to get Graylog running from fresh Kubernetes install to working instance

## Clone this Repository
Clone the repository and change directory into it.
```
git clone https://github.com/ihelpu-tech/graylog-kubernetes.git
cd graylog-kubernetes
```

## Create Namespace (Optional, but recommended)
Create a namespace for all of your resources to reside. This guide will keep everything under the `graylog` namespace, but it can be configured to suite your needs.

```
kubectl create namespace graylog
```

## Install Elasticsearch
This guide will use Elastic Cloud on Kubernetes (ECK) to install Elasticsearch. This guide references the official Elastic Co guide available here:
[https://www.elastic.co/downloads/elastic-cloud-kubernetes][eck]

1. Install the Elastic custom resource definition (CRD).
	```
	kubectl create -f https://download.elastic.co/downloads/eck/1.8.0/crds.yaml
	```

1. Install the Elastic Operator.
	```
	kubectl apply -f https://download.elastic.co/downloads/eck/1.8.0/operator.yaml
	```
	The operator will setup a new namespace, config maps, secrets, RBAC, a service, a stateful set, and a webhook to validate everything was setup correctly. The defaults should work fine, but now is the time to make changes if you need to modify any elastic settings.  
	For status updates or troubleshooting, you can monitor the logs by running: `kubectl -n elastic-system logs -f statefulset.apps/elastic-operator`

1. Configure and install Elasticsearch  
	* [Click to view Elastic Co's documentation for deploying Elasticsearch][elasticsearch]  
	```
	kubectl apply -f yaml/deploy-elasticsearch.yaml
	```

	Elasticsearch 7.10 is the lastest version that is support by graylog according to [Graylog's Documentation](https://docs.graylog.org/en/4.1/pages/installation.html#system-requirements).  

	The version can be updated by editing `spec.version` in the file `yaml/deploy-elasticsearch.yaml`  

	The number of node sets can be changed by editing `spec.nodeSets.count`. (The default is 1.)



## Install MongoDB
MongoDB will be installed using the Community Operator. This guide follows the documentation found on MongoDB's github page.
[MongoDB Kubernetes Community Operator][mongo]  

<!-- * Clone the MongoDB Community Operator Repository
	```
	git clone https://github.com/mongodb/mongodb-kubernetes-operator.git
	``` -->
The Mongo Operator gives us the option to install in the same namespace as resources or a different namespace. In keeping consistency with ECK, we will create a new namespace `mongo-system` and install the mongo operator in it.\
We will also need to make a few changes from the sample yaml files. This guide has already made the modifications and saves them as new yaml files. Please read the [install documentation][mongoinstall] if you need to customize the configuration for your cluster.

### Preparation
We need to configure the mongo operator to watch in different namespaces.
* Run the following command to create cluster-wide roles and role-bindings in the `mongo-system` namespace:
	```
	kubectl apply -f yaml/mongo/deploy/clusterwide
	```
	*This directory is a modified version of **mongodb-kubernetes-operator/deploy/clusterwide***

* For each namespace that you want the Operator to watch, run the following commands to deploy a Role, RoleBinding and ServiceAccount in that namespace. In our use case, we will select the `graylog` namespace:
	```
	kubectl apply -k mongodb-kubernetes-operator/config/rbac --namespace graylog
	```

### Install the Operator
*Taken from the [mongo install docs][mongoinstall]:*

The MongoDB Community Kubernetes Operator is a [Custom Resource Definition][crd] and a controller.

1. Change to the directory in which you cloned the repository.
	```
	cd mongodb-kubernetes-operator/
	```

1. Install the [Custom Resource Definitions][crd].\
	a. Invoke the following command:
	```
	kubectl apply -f config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
	```
	b. Verify that the Custom Resource Definitions installed successfully:
	```
	kubectl get crd/mongodbcommunity.mongodbcommunity.mongodb.com
	```

1. Install the necessary roles and role-bindings:\
	a. Invoke the following command:
	```
	kubectl apply -k config/rbac/ --namespace mongo-system
	```
	*We apply this to the `mongo-system` namespace since this is where we are installing the mongo operator. MongoDB resources will still be installed in the `graylog` namespace.*

	b. Verify that the resources have been created:
	```
	kubectl get role mongodb-kubernetes-operator --namespace mongo-system

	kubectl get rolebinding mongodb-kubernetes-operator --namespace mongo-system

	kubectl get serviceaccount mongodb-kubernetes-operator --namespace mongo-system
	```

1. Install the Operator.\
	a. Invoke the following kubectl command to install the modified Operator:
	```
	kubectl create -f ../yaml/mongo/manager/manager.yaml
	```

	b. Verify that the Operator installed successsfully:
	```
	kubectl get pods --namespace mongo-system
	```

View the [Mongo Update/Install Documentation][mongoinstall] for information about upgrading the operator.

Optional: View the docs on how to [test the MongoDB connection][testmongo]

### Install MongoDB Resources
*Elements taken from the [mongo deploy docs][mongodeploy]:*

1. Change directory back into the main branch.
	```
	cd ..
	```

2. Run the following script to deploy a mongoDB replica set:
	```
	future-script.bash
	```
	* The script automates the process found on the [mongo deploy docs][mongodeploy]. 
	* 

## Install Graylog




[eck]: https://www.elastic.co/downloads/elastic-cloud-kubernetes
[elasticsearch]: https://www.elastic.co/guide/en/cloud-on-k8s/1.8/k8s-deploy-elasticsearch.html
[mongo]: https://github.com/mongodb/mongodb-kubernetes-operator
[mongoinstall]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/install-upgrade.md
[mongodeploy]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/deploy-configure.md
[testmongo]: docs/test-mongo-connection.md
[crd]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/