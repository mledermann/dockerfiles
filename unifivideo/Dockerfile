FROM debian:stretch-slim
MAINTAINER https://github.com/mledermann

# modified from https://github.com/pducharme/UniFi-Video-Controller

ARG UVVERSION

# Set correct environment variables
ENV HOME /root
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

ENV UID 1002
ENV GID 1002

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg2

# Needed for installing openjdk-8 in slim
RUN mkdir -p /usr/share/man/man1

# Add mongodb repo, key, update and install needed packages
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4 && \
  echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" > /etc/apt/sources.list.d/mongodb-org-4.0.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils && \
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y  \
    jsvc \
    jq \
    moreutils \
    openjdk-8-jre-headless \
    patch \
    sudo \
    tzdata \
	lsb-release \
    mongodb-org-server \
    mongodb-org-shell \
    moreutils \
    wget \
	procps
	
# Get, install and patch unifi-video
RUN wget -q -O unifi-video.deb https://dl.ubnt.com/firmwares/ufv/v${UVVERSION}/unifi-video.Debian9_amd64.v${UVVERSION}.deb && \
  dpkg -i unifi-video.deb
  
  
RUN cp /usr/sbin/unifi-video /usr/sbin/unifi-video.orig && \
	grep -v ulimit /usr/sbin/unifi-video.orig > /usr/sbin/unifi-video

# Configuration and database volume
VOLUME ["/var/lib/unifi-video"]

# Video storage volume
VOLUME ["/var/lib/unifi-video/videos"]

# Video storage volume
VOLUME ["/var/lib/unifi-video/logs"]

# RTMP, RTMPS & RTSP via the controller
EXPOSE 1935/tcp 7444/tcp 7447/tcp

# Inbound Camera Streams & Camera Management (NVR Side)
EXPOSE 6666/tcp 7442/tcp

# UVC-Micro Talkback (Camera Side)
EXPOSE 7004/udp

# Camera Management
EXPOSE 7442/tcp

# Inbound Camera Streams
EXPOSE 6666/tcp

# NVR Discovery
EXPOSE 10001/udp

# HTTP & HTTPS Web UI + API
EXPOSE 7080/tcp 7443/tcp

# Video over HTTP & HTTPS
EXPOSE 7445/tcp 7446/tcp

COPY run-service.sh /usr/sbin/
RUN chmod +x /usr/sbin/run-service.sh

# Run it
ENTRYPOINT ["/usr/sbin/run-service.sh"]
