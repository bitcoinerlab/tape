#!/usr/bin/env bash

export TAPE_VOLUME_DIR="/root/tape-volume"
export BITCOIN_DIR="$TAPE_VOLUME_DIR/bitcoin"
ELECTRS_DB="$TAPE_VOLUME_DIR/electrs/db"
export INDEXDB="$TAPE_VOLUME_DIR/bitcoinjs-regtest-server-data/db"
mkdir -p "$BITCOIN_DIR" "$ELECTRS_DB" "$INDEXDB"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
$DIR/run_bitcoind_service.sh

#Run electrs:
/usr/bin/bitcoin-cli -datadir="$BITCOIN_DIR" -regtest getblockchaininfo # wait until the chain is synced...
#Note the 0.0.0.0 -> This is done so that it binds to 0.0.0.0 which means
#that it can accept calls from any external address. default is 127.0.0.1 which
#would anly let accept connections within the Docker image
electrs -vvvv --electrum-rpc-addr 0.0.0.0:60401 --http-addr 0.0.0.0:3002 --daemon-dir "$BITCOIN_DIR" --db-dir "$ELECTRS_DB" --network regtest --cors "*" &
ELECTRS_PID=$!

export RPCCOOKIE="$BITCOIN_DIR/regtest/.cookie"
export KEYDB=/root/regtest-data/KEYS
export ZMQ=tcp://127.0.0.1:30001
export RPCCONCURRENT=32
export RPC=http://localhost:18443
export PORT=8080

node /root/regtest-server/index.js &
NODE_PID=$!

(cd /root/esplora && PORT=5000 npm run dev-server)

cd

# Function to stop bitcoind and electrs gracefully
function graceful_shutdown {
  echo "Stopping Tape services gracefully..."
  /usr/bin/bitcoin-cli -datadir="$BITCOIN_DIR" -regtest stop
  kill -SIGTERM $ELECTRS_PID
  kill -SIGTERM $NODE_PID

  # Wait up to 30 seconds for each process to terminate
  timeout 30 wait $ELECTRS_PID || echo "Electrs did not terminate in time; force stopping." && kill -9 $ELECTRS_PID
  timeout 30 wait $NODE_PID || echo "Node process did not terminate in time; force stopping." && kill -9 $NODE_PID
}

# Trap SIGTERM and SIGINT to stop services gracefully
trap graceful_shutdown SIGTERM SIGINT

# Keep the script running to handle signals
wait
