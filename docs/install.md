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
Follow the [Install Elastic][install-elasticsearch] guide to get ECK running on your cluster.

## Install MongoDB
For simplicity, I would recommend using the free tier of the [MongoDB Atlas][mongo-atlas]. You will have plenty of storage for what Graylog will use and it is secure by default. The connection string from the node.js present seems to work just fine as long as you update the username and password. 
* Pro tip: Make sure your cluster has it's DNS settings correct so that pods can access resources from the internet. Deploy the graylogutils pod to test access to your MongoDB cluster before you deploy Graylog.

Follow the [Install Mongo][install-mongo] guide if it is a requirement for your project to get MongoDB running on your cluster.

## Install Graylog

*Documentation for Graylog can be found on here: [Graylog Docs][graylogdocs]*

Graylog can be installed two ways:
* [Automatically](#automatic-graylog-installation)
* [Manually](#manual-graylog-installation)

I would recommend reviewing the concepts of the manual installation first before using the automatic method to gain a better understanding of what's going on. *Manual installation guide needs completed.*

*The automatic deployment method has now been refined enough to be the recommended way to install Graylog.*

### Automatic Graylog Installation
Run the automatic script for easiest install:
```
./graylog-auto.bash
```
Most of the values are set at the automatic defaults. Just hit `Return/Enter`.

Changes may need to be made to configmap to adjust graylog settings. Run the following to edit the graylog settings configmap:
```
kubectl edit configmap --namespace graylog graylog-settings 
```

Seemlessly apply the new configmap by restarting the deployment:
```
kubectl rollout restart --namespace graylog deployment graylog-deployment
```

Check to make sure the changes were to the pod applied by running:
```
kubectl get pod --namespace graylog | grep graylog-deployment
$ graylog-deployment-76fc955ff-bd4jm

kubectl exec --namespace graylog -it graylog-deployment-76fc955ff-bd4jm -- cat /etc/graylog/server/server.conf
```

### Manual Graylog Installation

The configuration for Graylog will be defined by a [ConfigMap][configmap]. The values of the configmap are based on the [Graylog conf file][graylogconf]. Changes will need to be made to suite your setup.

The config map can be deployed manually by editing [graylog-settings.yaml][samplemap]. 

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
	Specify the elasticsearch host. This can be an in cluster or out of cluster resource. See [Connecting Elasticsearch](elasticsearch.md) for more information on testing Elasticsearch.	

1. `mongodb_uri`\
	Set the connection string for MongoDB. 

	If you are using MongoDB Atlas, the connection string from the node.js present seems to work just fine as long as you update the username and password.


There are also other options like timezone and root username that helpful to configure.


Once you have made the changes to the configmap, apply it using the following command:
```
kubectl apply -f yaml/graylog/graylog-settings.yaml
```

<!-- #### Deploy Graylog 
Now it's time for the fun part. Actually deploying Graylog. Let's get into it: -->










[eck]: https://www.elastic.co/downloads/elastic-cloud-kubernetes
[elasticsearch]: https://www.elastic.co/guide/en/cloud-on-k8s/1.8/k8s-deploy-elasticsearch.html
[install-elasticsearch]: install-elasticsearch.md

[mongo]: https://github.com/mongodb/mongodb-kubernetes-operator
[mongoinstall]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/install-upgrade.md
[mongodeploy]: https://github.com/mongodb/mongodb-kubernetes-operator/blob/master/docs/deploy-configure.md
[testmongo]: ../docs/test-mongo-connection.md
[install-mongo]: install-mongo.md
[mongo-atlas]: https://www.mongodb.com/atlas/database

[crd]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
[configmap]: https://kubernetes.io/docs/concepts/configuration/configmap/
[coredns]: https://coredns.io/plugins/kubernetes/
[dnsutils]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/

[graylogdocs]: https://docs.graylog.org/en/4.1/
[graylogconf]: https://github.com/Graylog2/graylog-docker/blob/4.1/config/graylog.conf
[samplemap]: ../yaml/graylog/graylog-settings.yaml