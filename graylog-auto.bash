#!/bin/bash

# Declare function to print out script usage
function usage() {
    cat <<USAGE

    Usage: $0 [args]

    Options:
        -n, --namespace:          	Set namespace.
        --mongo-uri:			Set the MongoDB URI.
	-r, --replicas:			Set the number of replicas.
	-t, --timezone:			Set default timezone

	-h, --help, --usage:    	Print this help message.
     
    MongoDB URI:
	--mongo-uri

	Sets the MongoDB URI. Make sure to use quotes around the URI when
	entering it as a flag. Otherwise, the shell may intepret special
	charactors in the URI as arguments.

	Ex: 
	graylog-auto --mongo-uri mongodb+srv://user:password@example.com/database?retryWrites=true&w=majority
	This would be intepreted in the shell as:
	mongodb+srv://user:password@example.com/database?retryWrites=true AND
	w=majority

	The correct way to set this flag is to put the URI in quotes so the
	shell parses the flag correctly:
	graylog-auto --mongo-uri "mongodb+srv://user:password@example.com/database?retryWrites=true&w=majority"
	
	Replicas:
	-r | --replicas (default is 1)

	Sets the number of replicas that will be used in the deployment.
	For better stability, this is configured to use one master pod
	and multiple worker pods. 
	
	Ex: -r 3 will create a deployment (graylog-master) with one master
	and a deployment (graylog-worker) with two worker pods.

	Ex: -r 1 will just create the graylog master deployment, but will
	write the manifest file for the worker nodes to:
	$(pwd)/yaml/graylog/graylog-deploy-worker.yaml
	The spec.replicas can be adjusted to suite your needs. Use kubectl
	to apply the manifest.

    Timezone:
	-t | --timezone

	This will set the default timezone for the root user.
	See http://www.joda.org/joda-time/timezones.html for a list of valid time zones.

USAGE
    exit 1
}

# Check to make sure that the replica option is a valid input
function checkReplica () {
	if ! [ "$REPLICAS" -eq "$REPLICAS" ] && [ $REPLICAS -gt 0 ];
		then 
			printf "\033[1;31mError: Invalid replica input! Must specify a whole number greater than 0.\033[0m\n"
			exit 1
	fi

}

# Set flags
echo
while [ "$1" != "" ]; do
	case $1 in
	-n | --namespace)
		shift
		NAMESPACE=$1
		echo "Using namespace: $NAMESPACE"
		;;

	--mongo-uri)
		shift
		MONGOURI=$1
		declare -r MONGOURI
		echo "Mongo URI: $MONGOURI"
		;;

	-r | --replicas)
		shift
		REPLICAS=$1
		checkReplica
		echo "Number of replicas: $REPLICAS"
		;;

	-t | --timezone)
		shift
		TIMEZONE=$1
		echo "Timezone: $TIMEZONE"
		;;
	
	-h | --help | --usage)
		usage
		exit 1
		;;

    	*)
		printf "\033[1;31mError: Invalid option!\033[0m\n"
		usage
		exit 1
		;;
	esac
	shift
done

echo
echo "Starting automatic Graylog install."
echo "See https://docs.graylog.org/en/4.1/pages/installation/manual_setup.html for details."
echo 
echo "=======Press 'Return/Enter' for Default Values======="
echo

if [ "$NAMESPACE" = "" ]; then
	read -p "Set namespace (graylog): " NAMESPACE
	NAMESPACE=${NAMESPACE:-graylog}
	echo
fi

if [ "$REPLICAS" = "" ]; then
	read -p "Set number of replicas (1): " REPLICAS
	REPLICAS=${REPLICAS:-1}
	checkReplica
	echo
fi

declare -i REPLICAS


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
		# Test for pwgen
		if ! command -v pwgen &> /dev/null
		then
			printf "\033[1;31mError: pwgen not installed!\033[0m\n"
			echo "Install pwgen: apt-get install pwgen"
			exit 1
		fi
		
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
done
echo
LOGINPASSWORD=$(echo -n $LOGINPASSWORD | shasum -a 256 | awk '{print$1}')
echo "Login password set"
echo

echo "=======Setup Elastic connection======="
echo "Use extract-es-cert.bash script to find and setup elasticsearch connection."
echo "It is recommended to use the script."
while true; do
	read -p "Automatically find and setup Elasticsearch connection? Y/n: " FINDELASTIC
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
						/bin/bash $(pwd)/extract-es-cert.bash --namespace $NAMESPACE
						echo "HTTPS script complete"
						echo 
						break;;
					[Nn]* ) echo "Skipping..."; break;;
					* ) echo "Please answer yes or no.";;
				esac
				unset yn
			done
						
			echo "Finding connection"
			ELASTICURI=$((kubectl get svc -n $NAMESPACE | grep es-http) | awk '{print $1}')
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
			ELASTICPASSWORD=$(kubectl get secret --namespace $NAMESPACE $(kubectl get secret --namespace $NAMESPACE | grep es-elastic-user | awk '{print$1}') -o go-template='{{.data.elastic | base64decode }}')
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
echo

echo "=======Mongo URI======="
echo "See https://docs.mongodb.com/manual/reference/connection-string/ for details"
if [ "$MONGOURI" = "" ]; then
	while true; do
		read -p "Enter MongoDB URI: " MONGOURI
		# echo
		# read -p "Confirm URI: " MONGOURI2
		# echo
		# [ "$MONGOURI" = "$MONGOURI2" ] && break || echo "Please try again"
		if [[ $MONGOURI == "" ]];
			then printf "\033[1;31mError: Mongo URI not specified. Must enter URI.\033[0m\n"
			else break
		fi
	done
fi
echo "Mongo URI: $MONGOURI"
echo

if [ "$TIMEZONE" = "" ]; then
	echo "=======Root Timezone======="
	echo "The time zone setting of the root user. See http://www.joda.org/joda-time/timezones.html for a list of valid time zones."
	read -p "Set root timezone (UTC): " TIMEZONE
	TIMEZONE=${TIMEZONE:-UTC}
	echo
fi
echo

echo "=======HTTP bind address======="
echo "The network interface used by the Graylog HTTP interface."
unset HTTPBIND
read -p "Set HTTP bind address (0.0.0.0:9000): " HTTPBIND
HTTPBIND=${HTTPBIND:-0.0.0.0:9000}
echo

# Name of generated configmap manifest files
MASTERCMNAME=graylog-settings-master
WORKERCMNAME=graylog-settings-worker

CMNAMESPACE=$NAMESPACE

# Path the file will be mounted within the pod
CONFIGPATH=/etc/graylog/server/

function findConfigmapTemplate() {
	if [ "$PODSETTINGSPATH" = "" ]; then
		read -p "Enter path to the graylog settings configmap: ($(pwd)/yaml/graylog/graylog-settings-default.yaml) " PODSETTINGSPATH
		PODSETTINGSPATH=${PODSETTINGSPATH:-$(pwd)/yaml/graylog/graylog-settings-default.yaml}
	fi
	echo "Using file at: $PODSETTINGSPATH"
	if ! [ -f $PODSETTINGSPATH ]; then
			printf "\033[1;31mError: graylog settings configmap not found.\033[0m\n"
			exit 1
	fi
}

function setConfigmap() {
	sed ' # Use sed to modify default config
		# Specify manifest details:
		s/name:.*/name: '"$CMNAME"'/; 
		s/namespace:.*/namespace: '"$CMNAMESPACE"'/; 

		# Set server.conf varibles:
		s/is_master.*/is_master \= '"$ISMASTER"'/; 
		s/password_secret.*/password_secret \= '"$PASSWORDSECRET"'/; 
		s/root_password_sha2.*/root_password_sha2 \= '"$LOGINPASSWORD"'/; 
		s#http_bind_address.*#http_bind_address \= '"$HTTPBIND"'#; 
		s/elasticsearch_hosts.*/elasticsearch_hosts \= https:\/\/'"$ELASTICUSERNAME"':'"$ELASTICPASSWORD"'@'"$ELASTICURI"':9200/;
		s#mongodb_uri.*#mongodb_uri \= '"$MONGOURI"'#; 
		s#root_timezone.*#root_timezone \= '"$TIMEZONE"'#; 
	' $INPUTSETTINGS > $OUTPUTSETTINGS
}

function findDeploymentTemplate() {
	if [ "$DEPLOYMENTSETTINGSPATH" = "" ]; then
		read -p "Enter path to the deployment config: ($(pwd)/yaml/graylog/graylog-deploy-default.yaml) " DEPLOYMENTSETTINGSPATH
		DEPLOYMENTSETTINGSPATH=${DEPLOYMENTSETTINGSPATH:-$(pwd)/yaml/graylog/graylog-deploy-default.yaml}
	fi
	echo "Using file at: $DEPLOYMENTSETTINGSPATH"
	if ! [ -f $DEPLOYMENTSETTINGSPATH ]; then
			printf "\033[1;31mError: deployment manifest not found.\033[0m\n"
			exit 1
	fi
}

function setDeployment() {
	sed ' # Use sed to modify deployment.
		s/name\:.graylog-deployment/name\:\ '"$DEPLOYMENTNAME"'/
		s/name\:.graylog-settings-master/name\:\ '"$SETTINGSNAME"'/
		s/replicas\:.[0-9]/replicas\:\ '"$DEPLOYMENTREPLICAS"'/
	' $INPUTDEPLOYMENT > $OUTPUTDEPLOYMENT
}

# Test for multiple replicas
if [ $REPLICAS -gt 1 ];
	then 
		echo "I am more"
		echo

		# Set master config
		echo "=======Creating Configmap======="
		findConfigmapTemplate
		INPUTSETTINGS=$PODSETTINGSPATH
		CMNAME=$MASTERCMNAME
		ISMASTER=true
		OUTPUTSETTINGS=yaml/graylog/graylog-settings-master.yaml
		setConfigmap
		kubectl apply -f $OUTPUTSETTINGS
		
		# Set worker config
		findConfigmapTemplate
		INPUTSETTINGS=$PODSETTINGSPATH
		CMNAME=$WORKERCMNAME
		ISMASTER=false
		OUTPUTSETTINGS=yaml/graylog/graylog-settings-worker.yaml
		setConfigmap
		kubectl apply -f $OUTPUTSETTINGS
		echo

		echo "=======Creating Deployment======="
		#Set Master Deployment
		# Step 1: Find the deployment template
		findDeploymentTemplate
		INPUTDEPLOYMENT=$DEPLOYMENTSETTINGSPATH
		OUTPUTDEPLOYMENT=yaml/graylog/graylog-deploy-master.yaml

		# Step 2: Configure the deployment based on the template.
		DEPLOYMENTNAME=graylog-master
		SETTINGSNAME=$MASTERCMNAME
		DEPLOYMENTREPLICAS=1
		setDeployment
		kubectl --namespace $NAMESPACE apply -f $OUTPUTDEPLOYMENT
		
		#Set Worker Deployment
		findDeploymentTemplate
		INPUTDEPLOYMENT=$DEPLOYMENTSETTINGSPATH
		OUTPUTDEPLOYMENT=yaml/graylog/graylog-deploy-worker.yaml
		
		DEPLOYMENTNAME=graylog-worker
		SETTINGSNAME=$WORKERCMNAME
		DEPLOYMENTREPLICAS=$(($REPLICAS - 1))		# The number of the replicas for the work deployment needs to be one less than the user defined.
		setDeployment
		kubectl --namespace $NAMESPACE apply -f $OUTPUTDEPLOYMENT

	else 
		echo "I am one"
		echo
		
		# Configmap
		echo "=======Creating Configmap======="
		findConfigmapTemplate
		INPUTSETTINGS=$PODSETTINGSPATH
		CMNAME=$MASTERCMNAME
		ISMASTER=true
		OUTPUTSETTINGS=yaml/graylog/graylog-settings-master.yaml
		setConfigmap
		kubectl apply -f $OUTPUTSETTINGS
		echo

		#Deployment
		echo "=======Creating Deployment======="
		# Step 1: Find the deployment template
		findDeploymentTemplate
		INPUTDEPLOYMENT=$DEPLOYMENTSETTINGSPATH
		OUTPUTDEPLOYMENT=yaml/graylog/graylog-deploy-master.yaml

		# Step 2: Configure the deployment based on the template.
		DEPLOYMENTNAME=graylog-master
		SETTINGSNAME=$MASTERCMNAME
		DEPLOYMENTREPLICAS=1
		setDeployment
		kubectl --namespace $NAMESPACE apply -f $OUTPUTDEPLOYMENT

fi

echo "=======Additional Settings======="
echo "Additoinal Graylog settings can be used by modifying the Graylog settings configmap."
echo "See https://github.com/Graylog2/graylog-docker/blob/4.1/config/graylog.conf to view the full default configuration"
echo "The config map can be modified by running: 'kubectl edit configmap --namespace $NAMESPACE ' "
echo

echo "=======Configmap and Deployment configured======="
echo "Run 'watch -x kubectl get all --namespace $NAMESPACE' to monitor deployment status"
echo

# Cleanup vars
unset ELASTICPASSWORD
unset PASSWORDSECRET
unset GENERATESECRET
unset LOGINPASSWORD
unset LOGINPASSWORD2


exit 0