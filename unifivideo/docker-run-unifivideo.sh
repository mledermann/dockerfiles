if [[ "$UID" -ne "0" ]]; then
  echo "MUST BE RUN AS ROOT"
  exit 1
fi

docker run --init -dit --restart unless-stopped \
  --privileged \
  -p 1935:1935 -p 7004:7004/udp -p 7442:7442 \
  -p 7443:7443 -p 7444:7444 -p 7445:7445 -p 7446:7446 -p 7447:7447 \
  -p 6666:6666 \
  -e UID=1003 -e GID=1003 -e TZ='America/Chicago' \
  -v /home/unifi-video/unifi-video:/var/lib/unifi-video:z \
  -v /home/unifi-video/logs:/var/lib/unifi-video/logs:z \
  -v /media/lib/unifi-video/videos:/var/lib/unifi-video/videos:z \
  --name unifivideo unifivideo:3.10.6
