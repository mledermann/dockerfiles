#!/bin/bash

HA_VERSION=stable



echo 'Checking for new version of homeassistant'
docker pull homeassistant/home-assistant:$HA_VERSION

homeassistant_running=`docker ps | grep homeassistant | wc -l`

if [[ "$homeassistant_running" -ne "0" ]]; then
  echo 'Stopping homeassistant'
  docker stop homeassistant
  echo 'Homeassistant stopped'
fi


homeassistant_exists=`docker ps --all | grep homeassistant | wc -l`

if [[ "$homeassistant_exists" -ne "0" ]]; then
  echo 'Removing old homeassistant container'
  docker rm homeassistant
  echo 'Old homeassistant removed'
fi

echo 'Starting homeassistant'

docker run -dit --restart unless-stopped -p 8123:8123 -p 8989:8989 -e TZ='America/Chicago' -v /home/mark/data/homeassistant/config:/config:z --name homeassistant homeassistant/home-assistant:$HA_VERSION

