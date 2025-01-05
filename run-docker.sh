#!/bin/sh
set -e -u

CONTAINER_HOME_DIR=/home/builder

UNAME=$(uname)
REPOROOT="$(dirname $(readlink -f $0))"

TERMUX_BUILDER_IMAGE_NAME="ghcr.io/termux/package-builder"
CONTAINER_NAME="termux-package-builder"

USER=builder

echo "Running container '$CONTAINER_NAME' from image '$TERMUX_BUILDER_IMAGE_NAME'..."

docker start $CONTAINER_NAME >/dev/null 2>&1 || {
  echo "Creating new container..."
  docker run \
    --detach \
    --name $CONTAINER_NAME \
    --volume $REPOROOT:$CONTAINER_HOME_DIR/termux-packages \
    --tty \
    $TERMUX_BUILDER_IMAGE_NAME

  if [ $(id -u) -ne 1000 -a $(id -u) -ne 0 ]; then
    echo "Changed builder uid/gid... (this may take a while)"
    docker exec $CONTAINER_NAME sudo chown -R $(id -u) $CONTAINER_HOME_DIR
    docker exec $CONTAINER_NAME sudo chown -R $(id -u) /data
    docker exec $CONTAINER_NAME sudo usermod -u $(id -u) builder
    docker exec $CONTAINER_NAME sudo groupmod -g $(id -g) builder
  fi
}

docker exec --interactive $CONTAINER_NAME "$@"
