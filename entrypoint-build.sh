#!/bin/sh

NETWORK=${_BUILD_NETWORK}

case "$_DAPPNODE_GLOBAL_CONSENSUS_CLIENT_PRATER" in
"prysm${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth")
    echo "Using prysm${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth"
    JWT_PATH="/security/prysm/jwtsecret.hex"
    ;;
"lighthouse${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth")
    echo "Using lighthouse${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth"
    JWT_PATH="/security/lighthouse/jwtsecret.hex"
    ;;
"teku${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth")
    echo "Using teku${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth"
    JWT_PATH="/security/teku/jwtsecret.hex"
    ;;
"nimbus${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth")
    echo "Using nimbus${_BUILD_CONSENSUS_PREFIX}.dnp.dappnode.eth"
    JWT_PATH="/security/nimbus/jwtsecret.hex"
    ;;
*)
    echo "Using default"
    JWT_PATH="/security/default/jwtsecret.hex"
    ;;
esac

# Print the jwt to the dappmanager
JWT=$(cat $JWT_PATH)
curl -X POST "http://my.dappnode/data-send?key=jwt&data=${JWT}"

#####################
# Datadir migration #
#####################
# UPSTREAM: 2021.08.03
# DAPPNODE: v0.1.7 to v0.1.8
# Datadir migration must be done manually according to https://github.com/ledgerwatch/erigon/releases/tag/v2021.08.03

PORT="${P2P_PORT:=30303}"
TORRENT_PORT="${BITTORRENT_PORT:=42069}"

DATADIR="/home/erigon/.local/share"

if [ -d "$DATADIR/erigon/chaindata" ]; then
    mv "$DATADIR/erigon/chaindata" "$DATADIR"
fi

############################
# Check database migration #
############################
# UPSTREAM: v2022.04.01
# DAPPNODE: v0.1.22 to v0.1.23

## Run for 5 secs to check the logs if we found:
## [EROR] [06-27|17:36:39.664] Erigon startup err="migrator.VerifyVersion: cannot upgrade major DB version for more than 1 version from 3 to 6, use integration tool if you know what you are doing"
## We need to re-sync

timeout -s 9 5 erigon --chain=${NETWORK} -datadir=/home/erigon/.local/share ${ERIGON_EXTRA_OPTS} 2>/tmp/initlog.txt
if grep -e "migrator.VerifyVersion: cannot upgrade major DB version for more than 1 version from 3 to 6, use integration tool if you know what you are doing" /tmp/initlog.txt; then
    echo "Cannot upgrade major DB version for more than 1 version from 3 to 6"
    echo "The database will be deleted as it needs to be resynchronized..."
    rm /home/erigon/.local/share/chaindata/*
fi

##########
# Erigon #
##########

exec erigon --datadir=${DATADIR} \
    --chain=${NETWORK} \
    --http.addr=0.0.0.0 \
    --http.vhosts=* \
    --http.corsdomain=* \
    --ws \
    --metrics \
    --metrics.addr=0.0.0.0 \
    --metrics.port=6060 \
    --pprof \
    --pprof.addr=0.0.0.0 \
    --pprof.port=6061 \
    --port=${P2P_PORT} \
    --torrent.port=${BITTORRENT_PORT} \
    --authrpc.jwtsecret=${JWT_PATH} \
    --override.terminaltotaldifficulty=10790000 \
    --authrpc.addr 0.0.0.0 \
    --authrpc.vhosts=* \
    ${ERIGON_EXTRA_OPTS}
