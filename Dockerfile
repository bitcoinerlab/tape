# -------------------------------------------------------
# Dockerfile for RewindBitcoin's Tape
# -------------------------------------------------------
#
# Quick Guide:
# 1. Building a Local Image:
#    $ docker build -t bitcoinerlab/tape .
#
# 2. Building for Multiple Platforms & Uploading to Docker Hub:
#    a. Login to Docker Hub:
#       $ docker login -u bitcoinerlab
#
#    b. Set up for multi-platform builds:
#       $ docker buildx create --use
#
#    c. Build & Push to Docker Hub:
#       $ docker buildx build --platform linux/amd64,linux/arm64 -t bitcoinerlab/tape . --push
#
# 3. Creating a Docker Volume for Persistent Data:
#    Create a Docker volume to store the blockchain, indexes, and regtest files:
#    $ docker volume create tape_data
#
#    This volume will be used to store the following directories:
#    - `/root/tape-volume/bitcoin`  : Bitcoin Core blockchain and wallet data
#    - `/root/tape-volume/electrs`  : Electrs index data
#    - `/root/tape-volume/bitcoinjs-regtest-server-data` : BitcoinJS server data
#
# 4. Running the Image:
#    $ docker run --name bitcoinerlab_tape_instance -v tape_data:/root/tape-volume -d -p 8080:8080 -p 60401:60401 -p 3002:3002 bitcoinerlab/tape
#
# If you get random GPG signature errors, clear Docker cache:
#    $ docker builder prune
#
# If you get resource exhausted errors, try restarting docker and deleting old images/volumes, then:
#   $ docker system prune -a --volumes

# Use Ubuntu 24.04 LTS as the base image
FROM ubuntu:24.04

# Set a maintainer label
LABEL maintainer="rewindbitcoin@gmail.com"

# Avoid user interaction when installing packages
ENV DEBIAN_FRONTEND=noninteractive

# Install Ubuntu security fixes before the build toolchain. Disable download
# retries while bootstrapping the APT fix for CVE-2026-109518.
RUN apt-get -o Acquire::Retries=0 update && \
    apt-get -o Acquire::Retries=0 install -y apt libapt-pkg6.0t64 libpcre2-8-0 && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' apt)" ge 2.8.4ubuntu0.1 && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libpcre2-8-0)" ge 10.42-4ubuntu2.2 && \
    apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    vim \
    wget

# Set the working directory
WORKDIR /root

CMD ["/bin/bash"]

# Bitcoin Core build dependencies; see its doc/build-unix.md.
RUN apt-get install -y build-essential libtool pkg-config bsdmainutils python3 &&\
  apt-get install -y libevent-dev libboost-dev &&\
  apt install -y libsqlite3-dev

# ZeroMQ libraries for Bitcoin Core notifications
RUN apt-get install -y libzmq3-dev

RUN wget https://bitcoincore.org/bin/bitcoin-core-30.4/bitcoin-30.4.tar.gz &&\
  echo "e7798e0693eb2dac4ebaf8ce761540882e3a1041259bb9083f484880eca20014  bitcoin-30.4.tar.gz" | sha256sum -c - &&\
  tar zxvf bitcoin-30.4.tar.gz

WORKDIR /root/bitcoin-30.4

# Local patches and their compatibility rationale: patches/README.md
COPY patches/bitcoin-regtest-halving.patch /root/tape-patches/
RUN git apply /root/tape-patches/bitcoin-regtest-halving.patch

RUN mkdir build && cd build && \
  cmake .. -DWITH_ZMQ=ON -DENABLE_IPC=OFF -DCMAKE_INSTALL_PREFIX=/usr && \
  make -j$(nproc) && make install

WORKDIR /root

RUN curl --silent --location https://deb.nodesource.com/setup_22.x | bash - &&\
  apt-get install -y nodejs

RUN mkdir /root/regtest-data && \
  echo "satoshi" > /root/regtest-data/KEYS


COPY run.sh run_bitcoind_service.sh install_leveldb.sh ./
COPY patches /root/tape-patches

RUN chmod +x install_leveldb.sh && \
  chmod +x run_bitcoind_service.sh && \
  chmod +x run.sh && \
  ./install_leveldb.sh

RUN git clone -b feat/zeromq6-compat https://github.com/bitcoinerlab/regtest-server.git

WORKDIR /root/regtest-server

RUN git checkout 70598710e6621afe718f22396f196c467210bc0d &&\
  git apply /root/tape-patches/regtest-dependencies.patch &&\
  npm ci &&\
  git apply /root/tape-patches/indexd-leveldown6.patch &&\
  node /root/tape-patches/indexd-leveldown6.test.cjs

# Install Blockstream electrs (rust & other dependencies)
WORKDIR /root
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN apt install -y git clang
ENV COMMIT_SHA=f1823d82b03dbd1dfef53f7b3611128dd2f4c1d2
RUN git clone https://github.com/blockstream/electrs
WORKDIR /root/electrs
RUN git checkout ${COMMIT_SHA}
RUN git apply /root/tape-patches/electrs-security.patch &&\
  cargo +stable build --release --locked
ENV PATH="/root/electrs/target/release:${PATH}"
# Electrum TCP and Esplora HTTP API ports
EXPOSE 60401 3002

# Clone and setup Esplora
WORKDIR /root
ENV COMMIT_SHA=09f8508d51f3f4da122b514a94fa4183740fd764
RUN git clone https://github.com/Blockstream/esplora
WORKDIR /root/esplora
RUN git checkout ${COMMIT_SHA}
RUN git apply /root/tape-patches/esplora-dependencies.patch &&\
  npm ci

# Environment variable to allow CORS from any domain for Esplora
ENV CORS_ALLOW=*
# API endpoint used by Esplora
ENV API_URL="http://localhost:3002"
# Expose Esplora server
EXPOSE 5000

ENTRYPOINT ["/root/run.sh"]

# Expose regtest-server
EXPOSE 8080
