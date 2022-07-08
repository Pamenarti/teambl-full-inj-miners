#!/usr/bin/env bash

[[ `ps aux | grep "./TBMiner" | grep -v grep | wc -l` != 0 ]] &&
  echo -e "${RED}$MINER_NAME miner is already running${NOCOLOR}" &&
  exit 1

cd $MINER_DIR/$MINER_VER

export LD_LIBRARY_PATH=${MINER_DIR}/lib:$LD_LIBRARY_PATH:${MINER_DIR}/${MINER_VER}

./TBMiner $(< ./miner.conf) --api --api-ip 127.0.0.1 --api-port ${MINER_API_PORT} 2>&1 | tee --append $MINER_LOG_BASENAME.log
