# Install MongoDB

*This guide is in alpha and not fully tested.*

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

[**Back to main installation guide**][install]


[install]: install.md

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
[samplemap]: ../yaml/graylog/graylog-settings.yaml