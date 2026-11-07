# BitcoinerLab/Tape

This repository is a fork of `@bitcoinerlab/tester`, adapted for running RewindBitcoin's Tape services.

Local build patches, their purpose and validation are documented in [patches/README.md](patches/README.md).

## Features

Tape provides the following services and configuration:

- **Operating System**: **Ubuntu 24.04 LTS**.
- **Bitcoin Core**: Version **30.4**.
- **Source Compilation**: Bitcoin Core is built from modified sources directly within the Docker image.
- **Halving Intervals**: Regtest uses a **210000-block** subsidy halving interval, matching mainnet.
- **Pre-mining**: Only creates a default wallet and mines initial blocks on the first run.
- **Data Management**: Utilizes a persistent docker volume for blockchain data storage.
- **Environment Variables**:
  - `PREMINED`: Sets the number of blocks to mine initially (integer).
  - `REINDEX`: Set to `1` to enable the `-reindex` flag when starting `bitcoind`.

Below is a quick start guide:

The Docker example uses a public development key and publishes ports on all
interfaces. Restrict access to trusted clients.

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
