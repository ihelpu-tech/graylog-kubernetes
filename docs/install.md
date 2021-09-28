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
	* We will deploy a modified version of Elastic's official file: 
	```
	kubectl apply -f yaml/deploy-elasticsearch.yaml
	```

	Elasticsearch 7.10 is the lastest version that is supported by graylog according to [Graylog's Documentation](https://docs.graylog.org/en/4.1/pages/installation.html#system-requirements).  

	The version can be updated by editing `spec.version` in the file `yaml/deploy-elasticsearch.yaml`  

	The number of node sets can be changed by editing `spec.nodeSets.count`. (The default is 1.)



## Install MongoDB
MongoDB will be installed using the Community Operator. This guide follows the documentation found on MongoDB's github page.
[MongoDB Kubernetes Community Operator][mongo]  

* Clone the MongoDB Community Operator Repository
	```
	git clone https://github.com/mongodb/mongodb-kubernetes-operator.git
	```
The Mongo Operator gives us the option to install in the same namespace as resources or a different namespace. In keeping consistency with ECK, we will create a new namespace `mongo-system` and install the mongo operator in it.\
We will also need to make a few changes from the sample yaml files. This guide has already made the modifications and saves them as new yaml files. Please read the [Mongo install documentation][mongoinstall] if you need to customize the configuration for your cluster.

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

1. Change to the directory in which you cloned the MongoBD repository.
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

### Install MongoDB Resources
*Elements taken from the [mongo deploy docs][mongodeploy]:*

1. Change directory back into the main branch.
	```
	cd ..
	```

1. Run the following script to deploy a mongoDB replica set:
	```
	./deploy-mongo.bash 
	```
	* The script automates the process found on the [mongo deploy docs][mongodeploy]. 

1. Verify that the MongoDB Replicaset is ready:
	```
	kubectl get mongodbcommunity --namespace graylog
	```

Optional: View the docs on how to [test the MongoDB connection][testmongo]

## Install Graylog

*Documentation for Graylog can be found on here: [Graylog Docs][graylogdocs]*

Graylog can be installed two ways:
* [Manually](###manual-graylog-installation)
* [Automatically](###automatic-graylog-installation)

I would recommend reviewing how the manual installation works first before using the automatic method.

### Manual Graylog Installation

The configuration for Graylog will be defined by a [ConfigMap][configmap]. The values of the configmap are based on the [Graylog conf file][graylogconf]. Changes will need to be made to suite your setup.

The config map can be deployed manually by editing [graylog-configmap.yaml][samplemap]. 

We need to make some basic changes to the graylog configuration before we apply the yaml file. If these changes aren't made, the deployment will fail. The critical changes are listed in the order they appeared in the [default graylog configuration][graylogconf].

1. `password_secret`\
	You MUST set a secret to secure/pepper the stored user passwords here. Use at least 64 characters.

	Generate one by using for example:
	```
	pwgen -N 1 -s 96
	```
	ATTENTION: This value must be the same on all Graylog nodes in the cluster. Changing this value after installation will render all user sessions and encrypted values in the database invalid. (e.g. encrypted access tokens)

1. `root_password_sha2`\
	You MUST specify a hash password for the root user (which you only need to initially set up the system and in case you lose connectivity to your authentication backend) This password cannot be changed using the API or via the web interface. If you need to change it, modify it in this file.

	Create one by using for example:
	```
	echo -n yourpassword | shasum -a 256
	```

1. `elasticsearch_hosts`\
	Specify the elasticsearch host. This can be an in cluster or out of cluster resource. This guide will use and recommend that you use the ECK instance that was previously deployed in this guide.

	- First, we need to find the domain name of elasticsearch cluster.

		List all of the services in the namespace:
		```
		kubectl get services --namespace graylog
		``` 
		Look for the `es-http` service:
		```
		$ kubectl get services --namespace graylog
		NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
		graylog-elasticsearch-es-default     ClusterIP   None             <none>        9200/TCP    4d5h
		graylog-elasticsearch-es-http        ClusterIP   10.105.118.252   <none>        9200/TCP    4d5h
		graylog-elasticsearch-es-transport   ClusterIP   None             <none>        9300/TCP    4d5h
		graylog-mongodb-svc                  ClusterIP   None             <none>        27017/TCP   65m
		```
		In this example, the service type is set to `ClusterIP` with an IP of `10.105.118.252`. Note that the IP is prone to changes and will most likely be different in your setup. We will use DNS to connect to Elasticsearch so a Domain Name Service like [CoreDNS][coredns] is required.

		If you hvae been following the guide so far with the default values, the DNS name for elasticsearch will be:
		```
		graylog-elasticsearch-es-http.graylog.svc.cluster.local
		```
		This follows the format of:
		```
		<elasticsearch-clustername>-es-http.<namespace>.svc.cluster.local
		```
		**Troubleshooting DNS Problems:**\
		[DNS Utils][dnsutils] is pod designed for troubleshooting issues with DNS. It will install in the default namespace. This can be changed by downloading the yaml file and editing `metadata.namespace` to your namespace.
		
		```
		wget https://k8s.io/examples/admin/dns/dnsutils.yaml
		vim dnsutils.yaml
		kubectl apply -f dnsutils.yaml
		```

		Once the DNS utils pod is running, use it to run `nslookup` to get the domain name of the service.
		```
		kubectl exec --namespace graylog -t -i pod/dnsutils -- nslookup <service name>
		```
		Running the command returns:
		```
		$ kubectl exec --namespace graylog -t -i pod/dnsutils -- nslookup graylog-elasticsearch-es-http
		Server:         10.96.0.10
		Address:        10.96.0.10#53

		Name:   graylog-elasticsearch-es-http.graylog.svc.cluster.local
		Address: 10.105.213.196
		```
		We are looking for the name of the elastic cluster. This is `graylog-elasticsearch-es-http.graylog.svc.cluster.local` in our case.
	- Use the domain name to fill in the connection string.
		`elasticsearch_hosts = http://graylog-elasticsearch-es-http.graylog.svc.cluster.local:9200`

1. `mongodb_uri`\
	Set the connection string for MongoDB. The same steps from finding the Elasticserach DNS entry apply for finding the Mongo DNS name if you are deploying mongo within the cluster. 

	If you are using MongoDB Atlas, the connection string from the node.js present seems to work just fine as long as you update the username and password.



Then apply the following command:
```
kubectl apply -f yaml/graylog/graylog-configmap.yaml
```

### Automatic Graylog Installation
*The automatic deployment script is still a work in progress. Check back later.*




[eck]: https://www.elastic.co/downloads/elastic-cloud-kubernetes
[elasticsearch]: https://www.elastic.co/guide/en/cloud-on-k8s/1.8/k8s-deploy-elasticsearch.html

[mongo]: https://github.com/mongodb/mongodb-kubernetes-operator
[mongoinstall]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/install-upgrade.md
[mongodeploy]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/deploy-configure.md
[testmongo]: ../docs/test-mongo-connection.md

[crd]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
[configmap]: https://kubernetes.io/docs/concepts/configuration/configmap/
[coredns]: https://coredns.io/plugins/kubernetes/
[dnsutils]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

[graylogdocs]: https://docs.graylog.org/en/4.1/
[graylogconf]: https://github.com/Graylog2/graylog-docker/blob/4.1/config/graylog.conf
[samplemap]: ../yaml/graylog/graylog-configmap.yaml