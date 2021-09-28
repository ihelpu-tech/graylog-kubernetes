FROM ubuntu:20.04
# Graylog testing image
RUN apt-get update

#General Networking	
RUN apt-get install --assume-yes \
	iputils-ping \
	dnsutils 
	

#Mongo
RUN apt-get install --assume-yes \
	gnupg \
	wget

RUN wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -
RUN echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
RUN apt-get update
RUN apt-get install -y mongodb-mongosh

#Elastic
RUN apt-get install --assume-yes \
	curl

#Graylog
