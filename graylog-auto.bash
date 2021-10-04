#!/bin/bash

echo "Starting automatic Graylog install."
echo "See https://docs.graylog.org/en/4.1/pages/installation/manual_setup.html for details."
echo 
echo "=======Press 'Return/Enter' for Default Values======="
echo

unset NAMESPACE
read -p "Set namespace (graylog): " NAMESPACE
NAMESPACE=${NAMESPACE:-graylog}
echo

echo "Set kubectl alias.\
\
Ex: kubectl, k, microk8s kubectl"
read -p "Set alias (kubectl): " KUBEALIAS
KUBEALIAS=${KUBEALIAS:-kubectl}
echo

echo "=======Graylog Secret======="
echo "You must set a secret that is used for password encryption and salting here."
echo "The server will refuse to start if it’s not set."
echo "If you run multiple graylog-server nodes, make sure you use the same password_secret for all of them!"
echo
unset PASSWORDSECRET
while true; do
    read -p "Auto generate secret? Y/n: " GENERATESECRET
    case $GENERATESECRET in
        [Yy]* ) 
		echo "Generating secret..."
		PASSWORDSECRET=$(pwgen -N 1 -s 96)
		echo "Secret: $PASSWORDSECRET"
		break;;
        [Nn]* ) 
		read -p "Specify secret: " PASSWORDSECRET
		echo "Secret set as: $PASSWORDSECRET"
		break;;
        * ) 
		echo "Please answer yes or no.";;
    esac
done
echo

echo "=======Root Password======="
echo "Password you will use for your initial login."
echo "Set this and you will be able to log in to the web interface with username admin and password you set here."
echo
while true; do
	read -s -p "Create Graylog root password: " LOGINPASSWORD
	echo
	read -s -p "Confirm password: " LOGINPASSWORD2
	echo
	[ "$LOGINPASSWORD" = "$LOGINPASSWORD2" ] && break || echo "Please try again"
	# [ "$password" = "$password2" ] && break || echo "Please try again"
done
echo
LOGINPASSWORD=$(echo -n $LOGINPASSWORD | shasum -a 256)
echo "Login password set"
echo

echo "=======Setup Elastic connection======="
echo "Use extract-es-cert.bash script to find and setup elasticsearch connection."
echo "It is recommended to use the script."
while true; do
	read -p "Automatically find and setup Elasticsearch connection? Y/n:  " FINDELASTIC
	case $FINDELASTIC in
		[Yy]* )
			echo "Starting automatic Elasticsearch setup..."
			echo
			while true; do
				unset yn
				read -p "Find Elastic HTTPS certificate and create config map? Y/n: " yn
				case $yn in
					[Yy]* ) 
						echo "Starting find https certificate script..."
						/bin/bash $(pwd)/extract-es-cert.bash
						echo "HTTPS script complete"
						echo 
						break;;
					[Nn]* ) echo "Skipping..."; break;;
					* ) echo "Please answer yes or no.";;
				esac
				unset yn
			done
			echo
			
			echo "Finding connection"
			# echo "Kube alias: $KUBEALIAS"
			ELASTICURI=$(($KUBEALIAS get svc -n $NAMESPACE | grep es-http) | awk '{print $1}')
			while true; do
				unset yn
				read -p "Use this URI: $ELASTICURI? Y/n: " yn
				case $yn in
					[Yy]* ) echo "Using found URI"; break;;
					[Nn]* ) read -p "Specify URI: " ELASTICURI; break;;
					* ) echo "Please answer yes or no.";;
				esac
				unset yn
			done
			
			unset ELASTICUSERNAME
			read -p "Enter elastic username (elastic): " ELASTICUSERNAME
			ELASTICUSERNAME=${ELASTICUSERNAME:-elastic}
			echo

			echo "Finding password..."
			echo "Kube alias: $KUBEALIAS"
			ELASTICPASSWORD=$($KUBEALIAS get secret --namespace $NAMESPACE $($KUBEALIAS get secret --namespace $NAMESPACE | grep es-elastic-user | awk '{print$1}') -o go-template='{{.data.elastic | base64decode }}')
			while true; do
				unset yn
				read -p "Use this password: $ELASTICPASSWORD? Y/n: " yn
				case $yn in
					[Yy]* ) echo "Using found password"; break;;
					[Nn]* ) 
						while true; do
							read -s -p "Enter elastic password: " ELASTICPASSWORD
							echo
							read -s -p "Confirm password: " ELASTICPASSWORD2
							echo
							[ "$ELASTICPASSWORD" = "$ELASTICPASSWORD2" ] && break || echo "Please try again"
							# [ "$password" = "$password2" ] && break || echo "Please try again"
						done
						break ;;
					* ) echo "Please answer yes or no.";;
				esac
				unset yn
			done

			break ;;
		[Nn]* )
			read -p "Enter elastic URI: " ELASTICURI
			echo
			unset ELASTICUSERNAME
			read -p "Enter elastic username (elastic): " ELASTICUSERNAME
			ELASTICUSERNAME=${ELASTICUSERNAME:-elastic}
			echo
			while true; do
				read -s -p "Enter elastic password: " ELASTICPASSWORD
				echo
				read -s -p "Confirm password: " ELASTICPASSWORD2
				echo
				[ "$ELASTICPASSWORD" = "$ELASTICPASSWORD2" ] && break || echo "Please try again"
				# [ "$password" = "$password2" ] && break || echo "Please try again"
			done
			break ;;
		* ) 
			echo "Please answer yes or no.";;

	esac
done

echo "=======Mongo URI======="
echo "See https://docs.mongodb.com/manual/reference/connection-string/ for details"
while true; do
	read -p "Enter MongoDB URI: " MONGOURI
	echo
	read -p "Confirm URI: " MONGOURI2
	echo
	[ "$MONGOURI" = "$MONGOURI2" ] && break || echo "Please try again"
done
echo

echo "=======Root Timezone======="
echo "The time zone setting of the root user. See http://www.joda.org/joda-time/timezones.html for a list of valid time zones."
unset TIMEZONE
read -p "Set root timezone (UTC): " TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}
echo

echo "=======HTTP bind address======="
echo "The network interface used by the Graylog HTTP interface."
unset HTTPBIND
read -p "Set HTTP bind address (0.0.0.0:9000): " HTTPBIND
HTTPBIND=${HTTPBIND:-0.0.0.0:9000}
echo

echo "=======Creating Configmap======="
echo "The config map will tell the Graylog Deployment what settings to use."
unset CONFIGMAPNAME
CONFIGMAPNAME=graylog-settings

CONFIGPATH=/etc/graylog/server/
# echo "Creating yaml file at $CONFIGPATH"
cat <<EOF > $(pwd)/$CONFIGMAPNAME.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CONFIGMAPNAME
  namespace: $NAMESPACE
  labels:
    app: graylog
data:
  server.conf: |
    # Welcome to k8s
    # Values were retrived from the default graylog configuration file.
    # https://raw.githubusercontent.com/Graylog2/graylog-docker/4.1/config/graylog.conf
    # Comments where removed.

    is_master = true
    node_id_file = /usr/share/graylog/data/config/node-id
    password_secret = $PASSWORDSECRET
    root_password_sha2 = $LOGINPASSWORD
    bin_dir = /usr/share/graylog/bin
    data_dir = /usr/share/graylog/data
    plugin_dir = /usr/share/graylog/plugin
    http_bind_address = $HTTPBIND
    elasticsearch_hosts = https://$ELASTICURI:9200
    rotation_strategy = count
    elasticsearch_max_docs_per_index = 20000000
    elasticsearch_max_number_of_indices = 5
    retention_strategy = delete
    elasticsearch_shards = 1
    elasticsearch_replicas = 0
    elasticsearch_index_prefix = graylog
    allow_leading_wildcard_searches = false
    allow_highlighting = false
    elasticsearch_analyzer = standard
    output_batch_size = 500
    output_flush_interval = 1
    output_fault_count_threshold = 5
    output_fault_penalty_seconds = 30
    processbuffer_processors = 5
    outputbuffer_processors = 3
    processor_wait_strategy = blocking
    ring_size = 65536
    inputbuffer_ring_size = 65536
    inputbuffer_processors = 2
    inputbuffer_wait_strategy = blocking
    message_journal_enabled = true
    message_journal_dir = data/journal
    lb_recognition_period_seconds = 3
    mongodb_uri = $MONGOURI
    mongodb_max_connections = 1000
    mongodb_threads_allowed_to_block_multiplier = 5
    proxied_requests_thread_pool_size = 32
    elasticsearch_discovery_default_user = $ELASTICUSERNAME
    elasticsearch_discovery_default_password = $ELASTICPASSWORD
    # elasticsearch_version = 7
    root_timezone = $TIMEZONE
EOF

# Apply configmap
$KUBEALIAS apply -f $(pwd)/$CONFIGMAPNAME.yaml
# Cleanup
rm $(pwd)/$CONFIGMAPNAME.yaml

echo
echo "=======Configmap Deployed======="
echo
echo "=======Additional Settings======="
echo "Additoinal Graylog settings can be used by modifying the Graylog settings configmap."
echo "See https://github.com/Graylog2/graylog-docker/blob/4.1/config/graylog.conf to view the full default configuration"
echo "The config map can be modified by running: '$KUBEALIAS edit configmap --namespace $NAMESPACE ' "
echo

echo "=======Creating Graylog Deployment======="
unset DEPLOYMENTPATH
read -p "Set path to graylog deployment yaml ($(pwd)/yaml/graylog/graylog-deploy.yaml): " DEPLOYMENTPATH
DEPLOYMENTPATH=${DEPLOYMENTPATH:-$(pwd)/yaml/graylog/graylog-deploy.yaml}
echo

echo "Deploying Graylog"
$KUBEALIAS apply --namespace $NAMESPACE -f $DEPLOYMENTPATH
echo

echo "Run 'watch -x $KUBEALIAS get all --namespace $NAMESPACE' to monitor deployment status"

# Cleanup vars
unset ELASTICPASSWORD
unset PASSWORDSECRET
unset GENERATESECRET
unset LOGINPASSWORD
unset LOGINPASSWORD2