# -------------------------------------------------------
# Dockerfile for rewindbitcoin Tape
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
# 3. Running the Image:
#    $ docker run -d -p 8080:8080 -p 60401:60401 -p 3002:3002 bitcoinerlab/tape
#
# Use Ubuntu 24.04 LTS as the base image
FROM ubuntu:24.04

# Set a maintainer label
LABEL maintainer="rewindbitcoin@gmail.com"

# Avoid user interaction when installing packages
ENV DEBIAN_FRONTEND=noninteractive

# Update packages and install essential ones
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    vim \
    wget

# Set the working directory
WORKDIR /root

# Start bash shell by default when a container starts
CMD ["/bin/bash"]

## I 'll need:
## --enable-txindex
## --with-zmq

#See: doc/build-unix.md
RUN apt-get install -y build-essential libtool autotools-dev automake pkg-config bsdmainutils python3 &&\
  apt-get install -y libevent-dev libboost-dev &&\
  apt install -y libsqlite3-dev

#we'll need zmq support
RUN apt-get install -y libzmq3-dev

RUN wget https://bitcoincore.org/bin/bitcoin-core-27.1/bitcoin-27.1.tar.gz &&\
  tar zxvf bitcoin-27.1.tar.gz

WORKDIR /root/bitcoin-27.1

# Modify chainparams.cpp before compiling so regtest has same halving as mainnet and we can be rich in regtest too
RUN sed -i 's/consensus.nSubsidyHalvingInterval = 150;/consensus.nSubsidyHalvingInterval = 210000;/' src/kernel/chainparams.cpp

RUN ./autogen.sh &&\
  ./configure --without-gui --enable-zmq --enable-txindex --disable-bdb --prefix=/usr &&\
  make -j 9 &&\
  make install

WORKDIR /root

RUN curl --silent --location https://deb.nodesource.com/setup_20.x | bash - &&\
  apt-get install -y nodejs

RUN mkdir /root/regtest-data && \
  echo "satoshi" > /root/regtest-data/KEYS


COPY run.sh run_bitcoind_service.sh install_leveldb.sh ./

RUN chmod +x install_leveldb.sh && \
  chmod +x run_bitcoind_service.sh && \
  chmod +x run.sh && \
  ./install_leveldb.sh

RUN git clone -b fix-bitcoinjs-lib-version https://github.com/bitcoinerlab/regtest-server.git

WORKDIR /root/regtest-server

# Change the checkout branch if you need to. Must fetch because of Docker cache
# RUN git fetch origin && \
#   git checkout ebee446d7c3b9071633764b39cdca3ac1b28d253

RUN npm i

# Install Blockstream electrs (rust & other dependencies)
WORKDIR /root
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN apt install -y git clang
RUN git clone https://github.com/blockstream/electrs
WORKDIR /root/electrs
RUN git checkout new-index
RUN cargo build --release
ENV PATH="/root/electrs/target/release:${PATH}"
# Expose electrs & esplora ports
EXPOSE 60401 3002

# Clone and setup Esplora
WORKDIR /root
ENV COMMIT_SHA=9067d8bf4323d8fea4cbf637b7c11ebc528d56e5
RUN git clone https://github.com/Blockstream/esplora
WORKDIR /root/esplora
RUN git checkout ${COMMIT_SHA}
RUN npm install --unsafe-perm

# Environment variable to allow CORS from any domain for Esplora
ENV CORS_ALLOW=*
# The esplora server:
ENV API_URL="http://localhost:3002"
# Expose Esplora server
EXPOSE 5000

ENTRYPOINT ["/root/run.sh"]

# Expose regtest-server
EXPOSE 8080
