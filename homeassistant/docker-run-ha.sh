#!/bin/bash
set -euo pipefail

# Run from the directory containing docker-compose.yml
cd "$(dirname "$(readlink -f "$0")")"

echo 'Checking for new versions of homeassistant and matter-server'
docker compose pull

# Only recreates containers whose image changed
echo 'Starting/updating containers'
docker compose up -d

docker compose ps
