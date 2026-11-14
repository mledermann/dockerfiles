#!/bin/bash

HA_VERSION=stable
MATTER_VERSION=latest



echo 'Checking for new version of homeassistant'
docker pull homeassistant/home-assistant:$HA_VERSION
docker pull ghcr.io/matter-js/matterjs-server:$MATTER_VERSION

homeassistant_running=`docker ps | grep homeassistant | wc -l`
matter_running=`docker ps | grep matter-server | wc -l`

restart_needed=0

if [[ "$matter_running" -ne "0" ]]; then
  running_id=`docker inspect --format json matter-server | jq '.[0] | .Image'`
  latest_id=`docker image inspect --format json ghcr.io/matter-js/matterjs-server:$MATTER_VERSION | jq '.[0] | .Id'`
  if [[ "$running_id" == "$latest_id" ]]; then
    echo "Matter Server already at latest version ${running_id}"
  else 
    echo "Updating matter-server to latest version ${latest_id} from ${running_id}"
    echo 'Stopping matter-server'
    docker stop matter-server
    echo 'Matter Server stopped'
    matter_restart_needed=1
  fi
fi

if [[ "$homeassistant_running" -ne "0" ]]; then
  running_id=`docker inspect --format json homeassistant | jq '.[0] | .Image'`
  latest_id=`docker image inspect --format json homeassistant/home-assistant:$HA_VERSION | jq '.[0] | .Id'`
  if [[ "$running_id" == "$latest_id" ]]; then
    echo "Homeassistant already at latest version ${running_id}"
  else
    echo "Updating homeassistant to latest version ${latest_id} from ${running_id}"
    echo 'Stopping homeassistant'
    docker stop homeassistant
    echo 'Homeassistant stopped'
    ha_restart_needed=1
  fi
fi

if [[ "$matter_restart_needed" -eq "0" && "$ha_restart_needed" -eq "0" ]]; then
  exit
fi 

homeassistant_exists=`docker ps --all | grep homeassistant | wc -l`
matterserver_exists=`docker ps --all | grep matter-server | wc -l`

if [[ "$homeassistant_exists" -ne "0" && "$ha_restart_needed" -ne "0" ]]; then
  echo 'Removing old homeassistant container'
  docker rm homeassistant
  echo 'Old homeassistant removed'
fi

if [[ "$matterserver_exists" -ne "0" && "$matter_restart_needed" -ne "0" ]]; then
  echo 'Removing old matter server container'
  docker rm matter-server
  echo 'Old matter server removed'
fi


if [[ "$matter_restart_needed" -ne "0" ]]; then
  echo 'Starting matter server'
  docker run -d --name matter-server --restart=unless-stopped \
    -v /home/mark/data/matter-js:/data --network=host ghcr.io/matter-js/matterjs-server:$MATTER_VERSION
fi

if [[ "$ha_restart_needed" -ne "0" ]]; then
  echo 'Starting homeassistant'
  docker run -dit --restart unless-stopped -p 8123:8123 -p 8989:8989 -e PYWEMO_CALLBACK_ADDRESS="192.168.0.31:8989" -e TZ='America/Chicago' -v /home/mark/data/homeassistant/config:/config:z --name homeassistant homeassistant/home-assistant:$HA_VERSION
fi
