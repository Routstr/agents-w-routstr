#!/bin/bash

set -e

# Relevant variables from lnvps-deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CDK_CLI_DIR="$SCRIPT_DIR/temp-routstr"
CDK_CLI_BIN="$CDK_CLI_DIR/cdk-cli-v0.13.0"
MINT_URL="https://mint.cubabitcoin.org"

# Set topup_amount to 21 as requested
topup_amount=21

echo "Testing token generation with topup_amount: $topup_amount"
echo "CDK_CLI_BIN: $CDK_CLI_BIN"
echo "MINT_URL: $MINT_URL"

# Logic to test (lines 927-954)
echo "Checking wallet balance..."
BALANCE_OUTPUT=$("$CDK_CLI_BIN" balance 2>&1)
# Extract balance for the specific mint URL
# Output format: 0: https://mint.cubabitcoin.org 3879 sat
CURRENT_BALANCE=$(echo "$BALANCE_OUTPUT" | grep "$MINT_URL" | awk '{print $(NF-1)}')

if [ -z "$CURRENT_BALANCE" ]; then
    CURRENT_BALANCE=0
fi

echo "Current Balance: $CURRENT_BALANCE"

if [ "$CURRENT_BALANCE" -lt "$topup_amount" ]; then
        echo "Using available balance: $CURRENT_BALANCE sats"
        topup_amount=$CURRENT_BALANCE
fi

SEND_OUTPUT=$(echo -e "$topup_amount\n\n" | "$CDK_CLI_BIN" send --mint-url "$MINT_URL" 2>&1 || true)
CASHU_TOKEN=$(echo "$SEND_OUTPUT" | grep -oP 'cashu\S+' || true)

if [ -z "$CASHU_TOKEN" ]; then
    echo "Error: Failed to generate Cashu token."
    echo "Debug Output from cdk-cli:"
    echo "$SEND_OUTPUT"
    exit 1
fi

echo "Generated Token: ${CASHU_TOKEN}"
echo "${CASHU_TOKEN}" > ./cashu_token.txt
