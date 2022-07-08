#!/usr/bin/env bash

show_watch=0

sleep_watch=1

function watch() {
  if [[ $show_watch -eq 1 ]]; then
    if [[ -z $2 ]]; then
      eval "echo $1=\$$1"
    else
      echo "$1=$2"
    fi
    [[ $sleep_watch != 0 ]] && sleep $sleep_watch
  fi
}

function expand_gpu_list() {
  for e in `echo $1 | tr ',' ' '`; do
    if [[ $e =~ '-' ]]; then
      eval "for i in {${e/-/..}}; do echo \$i; done"
    else
      echo $e
    fi
  done
}

function miner_ver() {
  local MINER_VER=$TEAMBLACKMINER_VER
  [[ -z $MINER_VER ]] && MINER_VER=$MINER_LATEST_VER
  echo $MINER_VER
}

function miner_config_echo() {
  local MINER_VER=`miner_ver`
  miner_echo_config_file "/hive/miners/$MINER_NAME/$MINER_VER/miner.conf"
}

function miner_config_gen() {
  local MINER_CONFIG="$MINER_DIR/$MINER_VER/miner.conf"
  echo $MINER_CONFIG
  mkfile_from_symlink $MINER_CONFIG

  [[ -z $TEAMBLACKMINER_TEMPLATE ]] && echo -e "${YELLOW}TEAMBLACKMINER_TEMPLATE is empty${NOCOLOR}" && return 1
  [[ -z $TEAMBLACKMINER_HOST ]] && echo -e "${YELLOW}TEAMBLACKMINER_HOST is empty${NOCOLOR}" && return 1
  [[ -z $TEAMBLACKMINER_PORT ]] && echo -e "${YELLOW}TEAMBLACKMINER_PORT is empty${NOCOLOR}" && return 1

  [[ -n $TEAMBLACKMINER_WORKER ]] && local worker="-w $TEAMBLACKMINER_WORKER" || local worker=''
  [[ -n $TEAMBLACKMINER_TLS ]] && local tls="-s" || local tls=''
  [[ -z $TEAMBLACKMINER_ALGO ]] && TEAMBLACKMINER_ALGO="ethash"

  if [[ -n $TEAMBLACKMINER_DISABLE_GPUS ]]; then
    for gpu in `expand_gpu_list ${TEAMBLACKMINER_DISABLE_GPUS// }`; do #delete spaces in gpuslist
      watch gpu
      gpu_bus_id=`gpu-detect listjson | jq -r ".[$gpu].busid"`
      watch gpu_bus_id
      disabled_gpus+="$gpu_bus_id "
    done
    watch disabled_gpus

    for (( i = 0; i < `gpu-detect AMD`; i++ )); do
      gpu_bus_id=`gpu-detect listjson | jq -r '[.[] | select(.brand == "amd")] | .['$i'].busid'`
      watch gpu_bus_id
      [[ ! $disabled_gpus =~ $gpu_bus_id ]] && enabled_amd+="$i,"
    done
    enabled_amd=${enabled_amd%%,}
    watch enabled_amd

    for (( i = 0; i < `gpu-detect NVIDIA`; i++ )); do
      gpu_bus_id=`gpu-detect listjson | jq -r '[.[] | select(.brand == "nvidia")] | .['$i'].busid'`
      watch gpu_bus_id
      [[ ! $disabled_gpus =~ $gpu_bus_id ]] && enabled_nvidia+="$i,"
    done
    enabled_nvidia=${enabled_nvidia%%,}
    watch enabled_nvidia

    GPUS=
    [[ -z $enabled_amd && -z $enabled_nvidia ]] && echo -e "${YELLOW}All GPUs are disabled. Check miner settings.${NOCOLOR}" && return 1
    [[ -n $enabled_amd ]] && GPUS="-Y [$enabled_amd] "
    [[ -n $enabled_nvidia ]] && GPUS+="-U [$enabled_nvidia]"
    watch GPUS
  fi

  if [[ $TEAMBLACKMINER_TLS -eq 1 ]]; then
    local port="-x $TEAMBLACKMINER_PORT"
  else
    local port="-p $TEAMBLACKMINER_PORT"
  fi

  local conf="-W $TEAMBLACKMINER_TEMPLATE \
              -H $TEAMBLACKMINER_HOST \
              $port \
              -a $TEAMBLACKMINER_ALGO \
              ${worker} \
              ${tls} \
              ${GPUS} \
              ${TEAMBLACKMINER_USER_CONFIG}"

  echo "$conf" > $MINER_CONFIG
}
