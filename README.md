# BitcoinerLab/Tape

This repository is a fork of `@bitcoinerlab/tester`, adapted for running RewindBitcoin's Tape services.

## Changes

This version introduces several upgrades and modifications:

- **Operating System**: Upgraded to **Ubuntu 24.04 LTS**.
- **Bitcoin Core**: Upgraded to version **27.1**.
- **Source Compilation**: Bitcoin Core is built from modified sources directly within the Docker image.
- **Halving Intervals**: Modified Bitcoin to use the same halving interval in regtest mode as on the mainnet.
- **Pre-mining**: Only creates a default wallet and mines initial blocks on the first run.
- **Data Management**: Utilizes a persistent docker volume for blockchain data storage.
- **New Environment Variables**:
  - `PREMINED`: Sets the number of blocks to mine initially (integer).
  - `REINDEX`: Set to `1` to enable the `-reindex` flag when starting `bitcoind`.

Below is a quick start guide:

```bash
# Clone the repo and build your own image:
git clone https://github.com/bitcoinerlab/tape.git
cd tape
docker build -t your_custom_tag .

# If you do not want to build the image locally, pull it from Docker Hub instead:
docker pull bitcoinerlab/tape

# Create a volume for persistent data storage:
docker volume create tape_data

# Run the container with the volume attached:
docker run --name bitcoinerlab_tape_instance \
  -v tape_data:/root/tape-volume \
  -d -p 8080:8080 -p 60401:60401 -p 3002:3002 bitcoinerlab/tape
# Replace bitcoinerlab/tape with your_custom_tag if you built your own image.

# Only for Admins: Multi-platform compilation and Docker Hub submission:
docker login -u bitcoinerlab
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t bitcoinerlab/tape . --push
```
