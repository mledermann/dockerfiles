#!/bin/bash

UNIFI_VERSION=5.12.66

docker run -dit --restart unless-stopped --init -p 8080:8080 -p 8443:8443 -p 3478:3478/udp -p 10001:10001/udp -e RUNAS_UID0=false -e UNIFI_UID=1001 -e UNIFI_GID=1001 -e TZ='America/Chicago' -e JVM_MAX_THREAD_STACK_SIZE=1280k -v /opt/UniFi:/unifi --name unifi jacobalberty/unifi:$UNIFI_VERSION

