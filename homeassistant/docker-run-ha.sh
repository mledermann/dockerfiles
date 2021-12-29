#!/bin/bash

HA_VERSION=stable

docker pull homeassistant/home-assistant:$HA_VERSION
docker run -dit --restart unless-stopped -p 8123:8123 -p 8989:8989 -e TZ='America/Chicago' -v /home/mark/data/homeassistant/config:/config:z --name homeassistant homeassistant/home-assistant:$HA_VERSION

