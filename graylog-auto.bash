#!/bin/bash

echo "Starting automatic Graylog install."
echo "See https://docs.graylog.org/en/4.1/pages/installation/manual_setup.html for details."

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

echo "=======Setup Elastic connection======="
echo "Use extract-es-cert.bash script to find and setup elasticsearch connection."
echo "It is recommended to use the script."
while true; do
	read -p "Automatically find and setup Elasticsearch connection? Y/n:  " FINDELASTIC
	case $FINDELASTIC in
		[Yy]* )
			while true; do
				unset yn
				read -p "Find Elastic HTTPS certificate and create config map? Y/n: " yn
				case $yn in
					[Yy]* ) 
						echo "Finding https certificate"
						/bin/bash $(pwd)/extract-es-cert.bash
						echo 
						break;;
					[Nn]* ) echo "Skipping..."; break;;
					* ) echo "Please answer yes or no.";;
				esac
				unset yn
			done
			
			echo "Finding connection"
			echo "Kube alias: $KUBEALIAS"
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