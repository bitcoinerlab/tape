# BitcoinerLab/Tape

This repository is a fork of `@bitcoinerlab/tester`, adapted for running RewindBitcoin's Tape services.

## Changes

This version introduces several upgrades and modifications:

- **Operating System**: Updated to **Ubuntu 24.04** from Ubuntu 22.04.
- **Bitcoin Version**: Upgraded to **27.1** from 26.0.
- **Halving Intervals**: Modified Bitcoin to use the same halving interval in regtest mode as on the mainnet.
- **Source Compilation**: Bitcoin Core is built from modified sources directly within the Docker image.
- **Pre-mining**: Automatically mines **20,100 blocks** upon initialization to provide 1 million matured BTC.
- Only create default wallet and mine initial blocks on first run.

For additional documentation on setup and configuration, please refer to the original `@bitcoinerlab/tester` project, but this is the TLDR:

```bash
docker login -u bitcoinerlab
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t bitcoinerlab/tape . --push
docker run -d -p 8080:8080 -p 60401:60401 -p 3002:3002 bitcoinerlab/tape
```
