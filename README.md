# BitcoinerLab/Tape

This repository is a fork of `@bitcoinerlab/tester`, adapted for running RewindBitcoin's Tape services.

## Changes

This version introduces several upgrades and modifications:

- **Operating System**: Updated to **Ubuntu 24.04** from Ubuntu 22.04.
- **Bitcoin Version**: Upgraded to **27.1** from 26.0.
- **Halving Intervals**: Modified Bitcoin to use the same halving interval in regtest mode as on the mainnet.
- **Source Compilation**: Bitcoin Core is built from modified sources directly within the Docker image.
- **Pre-mining**: Automatically mines **20,100 blocks** upon initialization to provide 1 million matured BTC.
- Only creates a default wallet and mines initial blocks on the first run.
- Uses a volume to store blockchain data for better data management and persistence.

Below is a quick start guide:

```bash
# Build and submit to Docker Hub:
docker login -u bitcoinerlab
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t bitcoinerlab/tape . --push

# If you did not build the image locally and need to pull it from Docker Hub:
docker pull bitcoinerlab/tape

# Create a volume for persistent data storage:
docker volume create tape_data

# Run the container with the volume attached:
docker run --name bitcoinerlab_tape_instance \
  -v tape_data:/root/tape-volume \
  -d -p 8080:8080 -p 60401:60401 -p 3002:3002 bitcoinerlab/tape
```
