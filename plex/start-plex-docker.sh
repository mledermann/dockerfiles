ID=`id -u`

if [[ ! $(groups | grep docker) ]]; then
  echo "User must be in the 'docker' group"
  exit 1
fi

if [[ -z "$PLEX_IP" ]]; then
  echo "Must set PLEX_IP to the ip to connect to"
  exit 1
fi
PLEX_VERSION=1.19.3.2764-ef515a800

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
-e PLEX_UID=1002 \
-e PLEX_GID=1002 \
-e CHANGE_CONFIG_DIR_OWNERSHIP=false \
-h PlexServer \
-v /home/plex/plexmediaserver:/config:z \
-v /home/plex/tmp:/transcode:z \
-v /media/lib:/media/lib:z \
plexinc/pms-docker:$PLEX_VERSION

