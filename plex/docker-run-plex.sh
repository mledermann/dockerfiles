ID=`id -u`

if [[ ! $(groups | grep docker) ]]; then
  echo "User must be in the 'docker' group"
  exit 1
fi

if [[ -z "$PLEX_IP" ]]; then
  PLEX_IP=`hostname -i`
  if [ "$PLEX_IP" == "::1%1 127.0.0.1" ]; then
    echo "Must set PLEX_IP to the ip to connect to"
    exit 1
  fi
fi

if [[ -z "$PLEX_CLAIM" ]]; then
  PLEX_CLAIM_PARAM=""
  # echo "Must set PLEX_CLAIM. Go to https://www.plex.tv/claim for code"
  # exit 1
else
  PLEX_CLAIM_PARAM=" -e PLEX_CLAIM=$PLEX_CLAIM "
fi

#PLEX_VERSION=1.25.8.5663-e071c3d62
PLEX_VERSION=latest

echo 'Checking for new version of plex'
docker pull plexinc/pms-docker:$PLEX_VERSION

plex_running=`docker ps | grep plex | wc -l`

if [[ "$plex_running" -ne "0" ]]; then
  echo 'Stopping plex'
  docker stop plex
  echo 'Plex stopped'
fi


plex_exists=`docker ps --all | grep plex | wc -l`

if [[ "$plex_exists" -ne "0" ]]; then
  echo 'Removing old plex container'
  docker rm plex
  echo 'Old plex removed'
fi

echo 'Starting plex'
docker run \
-d \
--restart unless-stopped \
--name plex \
-p 32400:32400/tcp \
-p 3005:3005/tcp \
-p 8324:8324/tcp \
-p 32469:32469/tcp \
-p 1900:1900/udp \
-p 32410:32410/udp \
-p 32412:32412/udp \
-p 32413:32413/udp \
-p 32414:32414/udp \
-e TZ="America/Chicago" \
-e ADVERTISE_IP="http://${PLEX_IP}:32400/" \
-e PLEX_UID=1001 \
-e PLEX_GID=1001 \
-e CHANGE_CONFIG_DIR_OWNERSHIP=false $PLEX_CLAIM_PARAM \
-h PlexServer \
-v /home/plex/plexmediaserver:/config:z \
-v /home/plex/tmp:/transcode:z \
-v /media/lib:/media/lib:z \
--device=/dev/dri:/dev/dri \
plexinc/pms-docker:$PLEX_VERSION

