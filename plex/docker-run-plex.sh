#!/bin/bash
set -euo pipefail

# Run from the directory containing docker-compose.yml
cd "$(dirname "$(readlink -f "$0")")"

if ! groups | grep -qw docker; then
  echo "User must be in the 'docker' group"
  exit 1
fi

if [[ -z "${PLEX_IP:-}" ]]; then
  PLEX_IP=$(hostname -i)
  if [[ "$PLEX_IP" == "::1%1 127.0.0.1" ]]; then
    echo "Must set PLEX_IP to the ip to connect to"
    exit 1
  fi
fi
export PLEX_IP

echo 'Checking for new version of plex'
docker compose pull

# Only recreates the container if the image changed
echo 'Starting/updating plex'
docker compose up -d

docker compose ps
