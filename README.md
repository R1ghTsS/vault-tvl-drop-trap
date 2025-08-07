# Vault TVL Drop Trap

A Drosera Trap that monitors vault Total Value Locked (TVL) and detects significant drops that could indicate exploits or mass withdrawals.

## Overview

This trap continuously monitors a specified vault contract and triggers an alert when the TVL drops by more than 20% within a 3-block period. This provides an early warning system for potential vault exploits or unusual withdrawal activity.

## How It Works

### Collect Function
- Reads `totalAssets()` or `totalSupply()` from the monitored vault
- Returns current TVL and block number
- Handles fallback between different vault interface methods

### ShouldRespond Function
- Analyzes historical TVL data from the last 3 blocks
- Calculates percentage drop between current and historical values
- Triggers response if drop exceeds 20% threshold
- Returns detailed message with drop percentage and TVL values

## Key Features

- **Real-time Monitoring**: Continuously tracks vault TVL every block
- **Configurable Threshold**: Currently set to 20% drop detection
- **Historical Analysis**: Compares current TVL with data from 2 blocks ago
- **Detailed Reporting**: Provides comprehensive incident details
- **Fallback Support**: Works with both `totalAssets()` and `totalSupply()` interfaces

## Configuration

### Trap Settings
- **Block Sample Size**: 3 blocks
- **Drop Threshold**: 20%
- **Cooldown Period**: 10 blocks
- **Min Operators**: 1
- **Max Operators**: 2

### Monitored Vault
- **Address**: `0x8cD9E6B7B4472e3d89abeBB902843BaC8f9b7b78` (MockVault for testing)
- **Interface**: ERC4626-like vault with `totalAssets()` function

## Setup Instructions

### Prerequisites
- Ubuntu/Linux environment
- Docker installed
- Foundry toolkit
- Drosera CLI
- Private key with Hoodi testnet ETH

### 1. Clone and Setup Project

```bash
mkdir ~/vault-tvl-drop-trap
cd ~/vault-tvl-drop-trap
forge init --template drosera-network/trap-foundry-template .
```

### 2. Install Dependencies

```bash
bun install
```

Update `package.json`:
```json
{
  "name": "@trap-examples/defi-automation/vault-tvl-drop-trap",
  "version": "1.0.0",
  "devDependencies": {
    "forge-std": "github:foundry-rs/forge-std#v1.8.1",
    "@openzeppelin/contracts": "4.9.0"
  },
  "dependencies": {
    "contracts": "https://github.com/drosera-network/contracts"
  }
}
```

### 3. Configure Foundry

Update `foundry.toml`:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["node_modules", "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/"]

[rpc_endpoints]
mainnet = "https://eth.llamarpc.com"
```

### 4. Deploy Mock Vault (for testing)

```bash
forge create src/MockVault.sol:MockVault \
  --rpc-url YOUR_RPC_URL \
  --private-key YOUR_PRIVATE_KEY \
  --constructor-args 1000000000000000000000 \
  --broadcast
```

### 5. Configure Trap

Update `drosera.toml`:
```toml
ethereum_rpc = "YOUR_RPC_URL"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.vaulttvldrop]
path = "out/VaultTVLDropTrap.sol/VaultTVLDropTrap.json"
response_contract = "YOUR_VAULT_ADDRESS"
response_function = "handleVaultDrop(string)"
cooldown_period_blocks = 10
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 3
private_trap = true
whitelist = ["YOUR_OPERATOR_WALLET_ADDRESS"]
```

### 6. Deploy Trap

```bash
DROSERA_PRIVATE_KEY=your_private_key drosera apply --eth-rpc-url YOUR_RPC_URL
```

### 7. Setup Operator

Create `docker-compose.yaml`:
```yaml
version: '3.8'

services:
  drosera-operator:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-operator
    ports:
      - "31313:31313"
      - "31314:31314"
    environment:
      - DRO__DB_FILE_PATH=/data/drosera.db
      - DRO__DROSERA_ADDRESS=0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
      - DRO__LISTEN_ADDRESS=0.0.0.0
      - DRO__DISABLE_DNR_CONFIRMATION=true
      - DRO__ETH__CHAIN_ID=560048
      - DRO__ETH__RPC_URL=YOUR_RPC_URL
      - DRO__ETH__BACKUP_RPC_URL=https://rpc.hoodi.ethpandaops.io
      - DRO__ETH__PRIVATE_KEY=${ETH_PRIVATE_KEY}
      - DRO__NETWORK__P2P_PORT=31313
      - DRO__NETWORK__EXTERNAL_P2P_ADDRESS=${VPS_IP}
      - DRO__SERVER__PORT=31314
      - RUST_LOG=info,drosera_operator=debug
    volumes:
      - drosera_data:/data
    restart: always
    command: node

volumes:
  drosera_data:
```

Create `.env`:
```env
ETH_PRIVATE_KEY=your_operator_private_key
VPS_IP=your_vps_public_ip
```

### 8. Start Operator

```bash
docker compose up -d
```

### 9. Register and Opt-in

```bash
# Register operator
drosera-operator register \
  --eth-rpc-url YOUR_RPC_URL \
  --eth-private-key YOUR_PRIVATE_KEY \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D

# Opt-in to trap
drosera-operator optin \
  --eth-rpc-url YOUR_RPC_URL \
  --eth-private-key YOUR_PRIVATE_KEY \
  --trap-config-address YOUR_TRAP_CONFIG_ADDRESS
```

## Testing

### Trigger TVL Drop

To test the trap, reduce the vault's TVL by more than 20%:

```bash
# Reduce TVL from 1000 to 700 (30% drop)
cast send YOUR_VAULT_ADDRESS "setTotalAssets(uint256)" 700000000000000000000 \
  --rpc-url YOUR_RPC_URL \
  --private-key YOUR_PRIVATE_KEY
```

### Monitor Logs

```bash
docker compose logs -f drosera-operator | grep "YOUR_TRAP_ADDRESS"
```

Look for:
- `ShouldRespond='true'` - Trap detected the drop
- `Successfully submitted claim` - Response executed
- `Cooldown period is active` - Trap entered cooldown

## Contract Addresses

### Hoodi Testnet
- **Drosera Core**: `0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D`
- **Mock Vault**: `0x8cD9E6B7B4472e3d89abeBB902843BaC8f9b7b78`
- **Trap Config**: `0xf479C47Aabc05c2eD86A10ECfff27743BFF10550`

## Monitoring

### Dashboard
- **Drosera App**: https://app.drosera.io/
- **Network**: Hoodi Testnet
- **Chain ID**: 560048

### Key Metrics
- Operator status (Green = Active)
- Trap execution frequency
- Response success rate
- Historical TVL data

## Customization

### Adjust Detection Threshold

Modify the percentage threshold in `VaultTVLDropTrap.sol`:
```solidity
// Change from 20% to desired threshold
if (dropPercentage > 30) { // 30% threshold
    // Trigger response
}
```

### Monitor Different Vaults

Update the hardcoded vault address:
```solidity
address public constant VAULT_ADDRESS = 0xYourVaultAddress;
```

### Custom Response Actions

Implement your own response contract with `handleVaultDrop(string)` function to take specific actions when the trap triggers.

## Troubleshooting

### Common Issues

1. **Trap not responding**: Check vault address is correct and accessible
2. **Operator offline**: Verify firewall settings for ports 31313/31314
3. **Insufficient data**: Wait 3+ blocks for historical data collection
4. **RPC issues**: Ensure RPC endpoint is stable and accessible

### Debug Commands

```bash
# Check vault TVL
cast call VAULT_ADDRESS "totalAssets()" --rpc-url YOUR_RPC_URL

# Check operator logs
docker compose logs --tail=50 drosera-operator

# Verify trap deployment
cast code TRAP_CONFIG_ADDRESS --rpc-url YOUR_RPC_URL
```

## Security Considerations

- Use separate private keys for testing vs production
- Monitor operator uptime and connectivity
- Regularly verify trap logic with test scenarios
- Keep RPC endpoints secure and reliable

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:
- Drosera Documentation: https://dev.drosera.io/
- GitHub Issues: Create an issue in this repository
- Community Discord: Join the Drosera community
