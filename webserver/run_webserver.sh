#!/usr/bin/env bash

ROOT_DIR=`pwd`

WORK_DIR="${ROOT_DIR}/data"
SAMPLE_TAR="${WORK_DIR}/sample.tar.gz"

# untar sample data
cd $WORK_DIR
if [ ! -d "${WORK_DIR}/logs" ]; then
    rm -rf ${WORK_DIR}/logs
    rm -rf ${WORK_DIR}/executions
    tar -xzvf $SAMPLE_TAR
fi

# server config
export SERVER_CONFIG="production"
export DATABASE_URL="sqlite:///${WORK_DIR}/logs/db.sqlite"
export ANOMALY_STATS_URL="sqlite:///${WORK_DIR}/logs/anomaly_stats.sqlite"
export ANOMALY_DATA_URL="sqlite:///${WORK_DIR}/logs/anomaly_data.sqlite"
export FUNC_STATS_URL="sqlite:///${WORK_DIR}/logs/func_stats.sqlite"
export EXECUTION_PATH="${WORK_DIR}/executions"

echo "run redis ..."
cd $ROOT_DIR
webserver/run-redis.sh &
sleep 10

echo "run celery ..."
python manager.py celery --loglevel=info &
sleep 10

echo "run webserver ..."
python manager.py runserver --host 0.0.0.0 --port 5001 --debug


