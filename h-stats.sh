#!/usr/bin/env bash
miner_stats=`curl --connect-timeout 2 --max-time $API_TIMEOUT --silent --noproxy '*' http://127.0.0.1:${MINER_API_PORT}/miner`
if [[ $? -ne 0 || -z $miner_stats ]]; then
  echo -e "${YELLOW}Failed to read $miner from localhost:{$MINER_API_PORT}${NOCOLOR}"
else
  khs=`echo $miner_stats | jq -r '.total_hashrate' | awk '{print $1/1000}'` #"
  local ac=`jq -r '.total_accepted' <<< "$miner_stats"`
  local rj=`jq -r '.total_rejected' <<< "$miner_stats"`

  local uptime=`echo $miner_stats | jq -r '.uptime_minutes' | awk '{print $1*60}'`
  local ver=`jq -r '.version' <<< "$miner_stats"`

  pool_stats=`curl --connect-timeout 2 --max-time $API_TIMEOUT --silent --noproxy '*' http://127.0.0.1:${MINER_API_PORT}/pool`
  local algo=`jq -r '.algo' <<< "$pool_stats"`
  #local pool=`jq -r '.url' <<< "$pool_stats"`

  gpus_stats=`curl --connect-timeout 2 --max-time $API_TIMEOUT --silent --noproxy '*' http://127.0.0.1:${MINER_API_PORT}/threads | jq '[to_entries | .[].value]'`

  local t_temp=$(jq '.temp' <<< $gpu_stats)
  local t_fan=$(jq '.fan' <<< $gpu_stats)
  local a_fans=""
  local a_temp=""

#  local bus_numbers=`jq '[.[].pcie_id]' <<< "$gpus_stats"`
  local bus_numbers=`jq -r '.[].pcie_id' <<< "$gpus_stats"`
  local all_bus_ids_array=(`cat "$GPU_DETECT_JSON" | jq -r '[ . | to_entries[] | select(.value) | .value.busid [0:2] ] | .[]'`)
  for bus_num in $bus_numbers; do
    for ((j = 0; j < ${#all_bus_ids_array[@]}; j++)); do
      if [[ "$(( 0x${all_bus_ids_array[$j]} ))" -eq "$bus_num" ]]; then
        a_fans+=$(jq .[$j] <<< $t_fan)" "
        a_temp+=$(jq .[$j] <<< $t_temp)" "
      fi
    done
  done
  bus_numbers=`echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.'`
  local temp=`echo ${a_temp[@]} | tr " " "\n" | jq -cs '.'`
  local fans=`echo ${a_fans[@]} | tr " " "\n" | jq -cs '.'`

  #local temp=`jq '[.[].gpu_temp]' <<< "$gpus_stats"`
  #local fans=`jq '[.[].fan]' <<< "$gpus_stats"`

  local hs=`jq '[.[].hashrate]' <<< "$gpus_stats"`
  local hs_units="hs"

  #local ag=`jq "[.accepted]" <<< "$gpu_stats"`
  #local rg=`jq "[.rejected]" <<< "$gpu_stats"`

  stats=$(jq --arg ac "$ac" --arg rj "$rj" \
         --arg algo "$algo" \
         --arg ver "$ver" --arg uptime "$uptime" \
         --argjson fan "$fans" --argjson temp "$temp" \
         --argjson hs "$hs" --arg hs_units "$hs_units"\
         --argjson bus_numbers "$bus_numbers" \
        '{$hs, $hs_units, $algo, $temp, $fan, $uptime,
          ar: [$ac, $rj], $bus_numbers, $ver}' <<< "$gpu_stats")
fi

  [[ -z $khs ]] && khs=0
  [[ -z $stats ]] && stats="null"
