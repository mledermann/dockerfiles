#if [[ "$UID" -ne "0" ]]; then
#  echo "MUST BE RUN AS ROOT"
#  exit 1
#fi

VERSION=3.10.12

docker build --build-arg UVVERSION=$VERSION -t unifivideo:$VERSION .
