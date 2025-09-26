#!/bin/bash

set -eux pipefail

env

pushd $RUN_DIR
git config --global --add safe.directory $RUN_DIR

mkdir -p data/grid
ln -s /Downloads/repeat_1rank data/grid/

# Install Redis

./webserver/run-redis.sh &

pushd /opt/spack-environment/ && \
    source /spack/spack/share/spack/setup-env.sh && \
    spack env activate .
popd

python -m pip install -r requirements.large.txt
python -m pip install -r requirements.txt

REDIS_CLI="./redis-stable/src/redis-cli"
function hold_for_redis () {
  while [[ ! -x $REDIS_CLI ]]; do
    echo wait for redis-cli: hold on 10 s
    sleep 10
  done
  OUTPUT="";
  while [[ "$OUTPUT" != "PONG" ]]; do
    OUTPUT=`$REDIS_CLI PING`;
    echo wait for redis: hold on 1 sec
    sleep 1
  done
}

set +e

hold_for_redis

set -e

# Fix configuration
CONF="./redis-stable/redis.conf"
sed -i '422s/^/# /' $CONF
sed -i '2017s/^/# /' $CONF
sed -i '2018s/^/# /' $CONF
sed -i "s/^protected-mode yes/protected-mode no/" $CONF
sed -i "s/^bind 127.0.0.1/bind 0.0.0.0/" $CONF
sed -i "s/^daemonize no/daemonize yes/" $CONF
sed -i "s|^dir ./|dir $RUN_DIR/|" $CONF
sed -i "s|^pidfile /var/run/redis_6379.pid|pidfile $RUN_DIR/redis.pid|" $CONF
killall -r '.*redis.*'

popd

# Install ngrok
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
      && echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" \
    | tee /etc/apt/sources.list.d/ngrok.list \
      && apt update \
      && apt install -y ngrok
ngrok config add-authtoken $NGROK_TOKEN

RUN_SCRIPT="./run.sh"
sed -i "s/^cycles=200/cycles=100/" $RUN_SCRIPT
sed -i "s/mpirun/mpirun --oversubscribe/" $RUN_SCRIPT

ngrok http 5002 &

CHIMBUKO_VIZ_ROOT=$RUN_DIR $RUN_SCRIPT

set +ex
