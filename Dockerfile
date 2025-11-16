FROM alpine:latest AS builder

# Build arguments for version
ARG BITCOIN_VERSION=30.0

WORKDIR /tmp

# Install build dependencies
RUN apk add --no-cache \
    boost-dev \
    build-base \
    ca-certificates \
    capnproto-dev \
    cmake \
    file \
    gnupg \
    git \
    libevent-dev \
    linux-headers \
    pkgconfig \
    samurai \
    sqlite-dev \
    zeromq-dev \
    wget

# Download source and signature
RUN wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}.tar.gz && \
    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS && \
    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc

# Import builder keys and verify
RUN git clone https://github.com/bitcoin-core/guix.sigs && \
    gpg --import guix.sigs/builder-keys/* && \
    gpg --verify SHA256SUMS.asc SHA256SUMS && \
    grep "bitcoin-${BITCOIN_VERSION}.tar.gz" SHA256SUMS | sha256sum -c

# Extract and build Bitcoin Core with CMake
RUN tar xzf bitcoin-${BITCOIN_VERSION}.tar.gz && \
    cd bitcoin-${BITCOIN_VERSION} && \
    cmake -B build -S . \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_BENCH=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_GUI=OFF \
        -DWITH_ZMQ=ON \
        -DENABLE_WALLET=ON && \
    cmake --build build -j$(nproc) --target bitcoind bitcoin-cli && \
    DESTDIR=/bitcoin-install cmake --install build --component bitcoind && \
    DESTDIR=/bitcoin-install cmake --install build --component bitcoin-cli && \
    strip /bitcoin-install/usr/bin/bitcoind /bitcoin-install/usr/bin/bitcoin-cli

# Runtime stage
FROM alpine:latest

# Install runtime dependencies only
# Bitcoin Core requires: libevent (networking), zeromq (notifications), 
# sqlite (descriptor wallets), boost (various utilities), capnproto (IPC), and C++ standard library
RUN apk add --no-cache \
    libevent \
    zeromq \
    sqlite-libs \
    boost-filesystem \
    boost-system \
    boost-thread \
    capnproto \
    libstdc++ \
    libgcc \
    su-exec

# Create bitcoin user and group with fixed UID/GID for consistency
RUN addgroup -g 523 bitcoin && \
    adduser -D -u 523 -G bitcoin bitcoin

# Copy binaries from builder
COPY --from=builder /bitcoin-install/usr/bin/bitcoin* /usr/local/bin/

# Copy entrypoint and healthcheck scripts
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Create data directory with correct ownership
ENV BITCOIN_DATA=/home/bitcoin/.bitcoin
RUN mkdir -p ${BITCOIN_DATA} && \
    chown -R bitcoin:bitcoin ${BITCOIN_DATA} && \
    chmod 700 ${BITCOIN_DATA}

VOLUME ["/home/bitcoin/.bitcoin"]

ENV BITCOIN_NETWORK=mainnet
EXPOSE 8332 8333

# Healthcheck: verify bitcoind is responding and syncing/synced with connections
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/bitcoind"]