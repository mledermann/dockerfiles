#!/bin/bash

HA_VERSION=stable

docker run -dit --restart unless-stopped -p 8123:8123 -e TZ='America/Chicago' --name homeassistant homeassistant/home-assistant:$HA_VERSION

