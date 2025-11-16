#!/bin/sh
set -e

# Use bitcoin-cli to check blockchain info
BLOCKCHAIN_INFO=$(bitcoin-cli -datadir="${BITCOIN_DATA}" getblockchaininfo 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Failed to connect to bitcoind"
    exit 1
fi

# Extract blocks and headers
BLOCKS=$(echo "$BLOCKCHAIN_INFO" | grep -o '"blocks": [0-9]*' | grep -o '[0-9]*')
HEADERS=$(echo "$BLOCKCHAIN_INFO" | grep -o '"headers": [0-9]*' | grep -o '[0-9]*')

if [ -z "$BLOCKS" ] || [ -z "$HEADERS" ]; then
    echo "Failed to parse blockchain info"
    exit 1
fi

echo "Blocks: $BLOCKS / Headers: $HEADERS"

# Check if we're syncing or synced
if [ "$BLOCKS" -lt "$HEADERS" ]; then
    # Still syncing - check if blocks are increasing (basic liveness check)
    echo "Syncing... ($BLOCKS/$HEADERS)"
    # During sync, we just verify bitcoind is responding
    exit 0
fi

# Once synced, check connection count
CONNECTION_COUNT=$(bitcoin-cli -datadir="${BITCOIN_DATA}" getconnectioncount 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Failed to get connection count"
    exit 1
fi

echo "Synced. Connections: $CONNECTION_COUNT"

# Must have at least 1 connection
if [ "$CONNECTION_COUNT" -eq 0 ]; then
    echo "No connections - something is wrong"
    exit 1
fi

echo "Healthy"
exit 0
