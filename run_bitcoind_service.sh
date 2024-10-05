#!/usr/bin/env bash

# Define a path to the flag file
FLAG_FILE="/root/.bitcoind_setup_done"

/usr/bin/bitcoind -server -regtest -txindex -zmqpubhashtx=tcp://127.0.0.1:30001 -zmqpubhashblock=tcp://127.0.0.1:30001 -rpcworkqueue=32 -fallbackfee=0.0002 &
disown
sleep 2

# Check if the initial setup has been done (wallet creation and mining)
if [ ! -f "$FLAG_FILE" ]; then
  echo "First-time setup: Creating wallet and mining blocks..."
  /usr/bin/bitcoin-cli -regtest createwallet default
  /usr/bin/bitcoin-cli -regtest loadwallet default
  ADDRESS=$(/usr/bin/bitcoin-cli -regtest getnewaddress "" bech32)
  #Mine 1 million btc and be rich!
  /usr/bin/bitcoin-cli -regtest generatetoaddress 20100 $ADDRESS
  # Create a flag file to indicate that the setup has been completed
  touch "$FLAG_FILE"
else
  echo "Skipping setup. Wallet and blocks already created."
  /usr/bin/bitcoin-cli -regtest loadwallet default
fi
