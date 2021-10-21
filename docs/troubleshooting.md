# Troubleshooting
Guide to troubleshoot problems that may arise when deploying Graylog on Kubernetes.

## Everything is always a DNS issue...
DNS is a very important aspect of any Kubernetes cluster. Before smashing your head against the wall wondering why your graylog pods keep crashing, check to make sure that they can reach Elasticsearch and MongoDB. 

To assist in finding errors, I created a [graylogutils][graylogutils] docker image.
Make sure you are in the cloned repository folder run the following to deploy the image to your cluster:
```
kubectl --namespace graylog apply -f yaml/graylog-testutils.yaml
```
Once it is ready run the following to get a shell inside the pod:
```
kubectl --namespace graylog exec -it graylogutils -- bash
```

A simple way to test whether your pods can ready out to the internet is to run `apt-get update` and see if it can connect. 
The pod also has many networking utilities (such as nslookup, ping, and traceroute) built-in to help with troubleshooting. It also includes `mongosh` so you can test your mongo deployment. 

Cleanup the pod once you are done:
```
kubectl --namespace graylog delete pod graylogutils
```

## Get configuration and logs
Sometimes it is helpful to be able to review the logs to see why your graylog pod is crashing. In order to see the logs from the Graylog pod, you will need to change the deployment's run command in the [graylog-deploy][graylog-deploy] yaml file.
Under spec.template.spec.containers, change the following from:
```
- name: graylog
        image: graylog/graylog:4.1-jre11
        # Testing command to prevent the pod from dying while under development. 
        # command: ['sh', '-c', 'echo "Hello, Kubernetes!" && sleep 3600']
        command: ['sh', '-c', '/usr/share/graylog/bin/graylogctl run']
```
To:
```
- name: graylog
        image: graylog/graylog:4.1-jre11
        # Testing command to prevent the pod from dying while under development. 
        command: ['sh', '-c', 'echo "Hello, Kubernetes!" && sleep 3600']
        # command: ['sh', '-c', '/usr/share/graylog/bin/graylogctl run']
```

This will put the deployment in testing mode so you can get a shell inside the pod. 
To do this, I wrote a script that will conveniently find the pod name enter an interactive bash shell. From the root of the cloned repository, run:
```
./runshellinpod.bash
```
Once you are in the pod, run `bin/graylogctl start` to start the graylog service. Logs will be printed to `log/graylog-server.log`. Run `bin/graylogctl status` to see if graylog is running. Note that is may take up to a couple of minutes for certain items to timeout and cause the service to fail.  I created a script to extract a copy of the logs and the current configuration to your local machine. Run:
```
./extract-log-and-conf.bash
```
This will put a copy of `server.conf` and `graylog-server.log` in your current working directory.

[graylogutils]: https://hub.docker.com/r/benihelputech/graylogtester
[graylog-deploy]: ../yaml/graylog/graylog-deploy.yaml