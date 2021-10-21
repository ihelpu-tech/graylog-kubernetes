# Install Elasticsearch
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
	kubectl apply --namespace graylog -f yaml/elastic/deploy-elasticsearch.yaml
	```

	Elasticsearch 7.10 is the lastest version that is supported by graylog according to [Graylog's Documentation](https://docs.graylog.org/en/4.1/pages/installation.html#system-requirements).  

	The version can be updated by editing `spec.version` in the file `yaml/elastic/deploy-elasticsearch.yaml`  

	The number of node sets can be changed by editing `spec.nodeSets.count`. (The default is 1.)

1. Check Elasticsearch Deployment
	Make sure Elasticsearch is ready:
	```
	kubectl get elasticsearch --namespace graylog
	```
	Make sure your deployment health is `green` before proceeding.

<br />
<br />

[**Back to main installation guide**][install]

[eck]: https://www.elastic.co/downloads/elastic-cloud-kubernetes
[elasticsearch]: https://www.elastic.co/guide/en/cloud-on-k8s/1.8/k8s-deploy-elasticsearch.html
[install]: install.md