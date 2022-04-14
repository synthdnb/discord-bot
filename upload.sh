#!/bin/sh
docker buildx build --platform linux/amd64 --push -t synthdnb/gbf-discord-bot .
