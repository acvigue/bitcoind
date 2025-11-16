FROM alpine:latest AS builder

# Build arguments for version and architecture detection
ARG TARGETPLATFORM
ARG BITCOIN_VERSION=30.0

# Install dependencies for downloading and verifying
RUN apk add --no-cache \
    ca-certificates \
    gnupg \
    wget \
    git

WORKDIR /tmp

# Download SHA256SUMS and signature file
RUN wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS && \
    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc

RUN git clone https://github.com/bitcoin-core/guix.sigs
RUN gpg --import guix.sigs/builder-keys/*

# Verify the SHA256SUMS file signature
RUN gpg --verify SHA256SUMS.asc SHA256SUMS

# Download correct binary based on architecture and verify checksum
RUN case "${TARGETPLATFORM}" in \
    "linux/amd64") BITCOIN_ARCH="x86_64-linux-gnu" ;; \
    "linux/arm64") BITCOIN_ARCH="aarch64-linux-gnu" ;; \
    "linux/arm/v7") BITCOIN_ARCH="arm-linux-gnueabihf" ;; \
    *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz && \
    grep "bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz" SHA256SUMS | sha256sum -c && \
    tar -xzf bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz && \
    install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${BITCOIN_VERSION}/bin/*

# Runtime stage
FROM alpine:latest

# Install runtime dependencies only
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    su-exec

# Create bitcoin user and group with fixed UID/GID for consistency
RUN addgroup -g 523 bitcoin && \
    adduser -D -u 523 -G bitcoin bitcoin

# Copy binaries from builder
COPY --from=builder /usr/local/bin/bitcoin* /usr/local/bin/

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
CMD ["bitcoind"]