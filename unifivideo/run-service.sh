#!/bin/bash

usermod -o -u "${UID}" unifi-video &> /dev/null
groupmod -o -g "${GID}" unifi-video &> /dev/null

/usr/sbin/unifi-video --debug start
sleep infinity
