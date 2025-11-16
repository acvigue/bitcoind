# Bitcoin Core Docker Image

A minimal, secure Docker image for running Bitcoin Core on Alpine Linux.

## Features

- **Minimal footprint**: Built on Alpine Linux
- **Security-focused**:
  - GPG signature verification using official Bitcoin Core builder keys
  - SHA256 checksum verification
  - Non-root user (UID/GID 523)
  - Principle of least privilege
- **Multi-architecture support**: amd64, arm64, arm/v7
- **Health checks**: Monitors blockchain sync and network connectivity
- **Flexible configuration**: Support for mainnet, testnet, regtest, and signet

## Quick Start

### Run Bitcoin Core (mainnet)

```bash
docker run -d \
  --name bitcoind \
  -v bitcoin-data:/home/bitcoin/.bitcoin \
  -p 8332:8332 \
  -p 8333:8333 \
  bitcoind:latest
```

### Run with testnet

```bash
docker run -d \
  --name bitcoind-testnet \
  -e BITCOIN_NETWORK=testnet \
  -v bitcoin-testnet-data:/home/bitcoin/.bitcoin \
  -p 18332:18332 \
  -p 18333:18333 \
  bitcoind:latest
```

## Building

### Single architecture

```bash
docker build -t bitcoind:latest .
```

### Multi-architecture with buildx

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t bitcoind:latest \
  .
```

### Custom Bitcoin version

```bash
docker build \
  --build-arg BITCOIN_VERSION=28.0 \
  -t bitcoind:28.0 \
  .
```

## Configuration

### Environment Variables

| Variable             | Default                  | Description                                               |
| -------------------- | ------------------------ | --------------------------------------------------------- |
| `BITCOIN_NETWORK`    | `mainnet`                | Network to run: `mainnet`, `testnet`, `regtest`, `signet` |
| `BITCOIN_DATA`       | `/home/bitcoin/.bitcoin` | Data directory path                                       |
| `BITCOIN_EXTRA_ARGS` | -                        | Additional arguments for `bitcoin.conf`                   |
| `BITCOIN_WALLETDIR`  | -                        | Custom wallet directory                                   |
| `CREATE_WALLET`      | `true`                   | Auto-create wallet if it doesn't exist                    |
| `BITCOIN_TORCONTROL` | -                        | Tor control endpoint (format: `host:port`)                |

### Ports

| Network | RPC Port | P2P Port |
| ------- | -------- | -------- |
| Mainnet | 8332     | 8333     |
| Testnet | 18332    | 18333    |
| Regtest | 18443    | 18444    |
| Signet  | 38332    | 38333    |

## Examples

### With custom configuration

```bash
docker run -d \
  --name bitcoind \
  -e BITCOIN_NETWORK=mainnet \
  -e BITCOIN_EXTRA_ARGS="txindex=1" \
  -v bitcoin-data:/home/bitcoin/.bitcoin \
  -p 8332:8332 \
  -p 8333:8333 \
  bitcoind:latest
```

### With Tor support

```bash
docker run -d \
  --name bitcoind \
  -e BITCOIN_TORCONTROL=tor:9051 \
  -v bitcoin-data:/home/bitcoin/.bitcoin \
  -p 8332:8332 \
  -p 8333:8333 \
  bitcoind:latest
```

### Regtest for development

```bash
docker run -d \
  --name bitcoind-regtest \
  -e BITCOIN_NETWORK=regtest \
  -v bitcoin-regtest-data:/home/bitcoin/.bitcoin \
  -p 18443:18443 \
  -p 18444:18444 \
  bitcoind:latest
```

## Using bitcoin-cli

```bash
# Get blockchain info
docker exec bitcoind bitcoin-cli -datadir=/home/bitcoin/.bitcoin getblockchaininfo

# Get wallet info
docker exec bitcoind bitcoin-cli -datadir=/home/bitcoin/.bitcoin getwalletinfo

# Create a new address
docker exec bitcoind bitcoin-cli -datadir=/home/bitcoin/.bitcoin getnewaddress
```

## Health Check

The image includes a health check that:

1. Monitors blockchain sync progress (blocks vs headers)
2. Verifies network connectivity (connection count)
3. Reports "unhealthy" if bitcoind is unresponsive or has no connections

Check container health:

```bash
docker inspect --format='{{.State.Health.Status}}' bitcoind
```

## Data Persistence

Bitcoin Core data is stored in `/home/bitcoin/.bitcoin`. Always use a volume to persist blockchain data:

```bash
# Create a named volume
docker volume create bitcoin-data

# Or mount a host directory
docker run -d \
  -v /path/to/bitcoin/data:/home/bitcoin/.bitcoin \
  bitcoind:latest
```

## Security

This image follows security best practices:

- **GPG Verification**: All Bitcoin Core releases are verified using official builder keys from the [guix.sigs](https://github.com/bitcoin-core/guix.sigs) repository
- **Checksum Verification**: SHA256 checksums are verified before installation
- **Non-root User**: Runs as user `bitcoin` (UID/GID 523)
- **Minimal Dependencies**: Only essential runtime libraries included
- **Read-only Root**: Compatible with `--read-only` flag

## License

This Docker image configuration is provided as-is. Bitcoin Core is licensed under the MIT License.

## Resources

- [Bitcoin Core](https://bitcoincore.org/)
- [Bitcoin Core Documentation](https://bitcoin.org/en/bitcoin-core/)
- [Bitcoin Core Repository](https://github.com/bitcoin/bitcoin)
