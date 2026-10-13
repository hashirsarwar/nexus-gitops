#!/bin/sh
set -eu

exec curl --fail --silent --show-error \
  --connect-timeout 5 \
  --max-time 10 \
  "$HEALTH_URL"
