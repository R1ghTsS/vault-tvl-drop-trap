# Vault TVL Drop Trap (Enhanced)

A **Drosera Trap** that monitors a vault’s **Total Value Locked (TVL)** and triggers when the **current TVL falls from the recent peak by at least a threshold** (default **5%**) over a sampled block window. Built with **Foundry** and friendly to **private RPC** testing.

> **What’s new vs the original**
>
> - Peak → current logic over a sliding window (not just a single look‑back)
> - Human‑readable incident details (drop bps, absolute delta, window bounds, sample count)
> - Safer “assets reader”: tries `totalAssets()` then falls back to `totalSupply()`
> - Example response contract that emits `VaultDrop(string)`
> - End‑to‑end steps for private RPC, operator, and verification

---

## Overview

This trap continuously samples a specified vault contract and **fires** when the TVL **drops by the configured threshold** within the recent sample window. Useful for early warning of mass withdrawals or exploits.

### How It Works

**Collect Function**
- Reads `totalAssets()` or `totalSupply()` from the monitored vault
- Returns current TVL and the block number
- Handles fallback between different vault interfaces

**ShouldRespond Function**
- Scans all samples in the window to find **peak TVL**
- Compares **current** vs **peak**; calculates **bps drop** and **absolute delta**
- Triggers if `drop >= DROP_THRESHOLD_BPS` and (optionally) above `MIN_ABSOLUTE_DROP`

### Key Features
- **Real-time sampling:** checks vault TVL every block via operator sampling
- **Configurable threshold:** default **5%** (`DROP_THRESHOLD_BPS = 500`)
- **Noise guard:** optional absolute floor `MIN_ABSOLUTE_DROP`
- **Works with 4626 & ERC20-like vaults:** uses `totalAssets()` then `totalSupply()`
- **Readable incidents:** clear message string with context (bps, deltas, blocks, samples)

---

## Requirements

- **Foundry** (forge/cast/anvil/chisel)
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```
- **Node 18+** (dev tooling only)
- Access to an **Ethereum-compatible RPC** (public or your private one)
- A funded **private key** for your target chain

> Example values below assume **Hoodi testnet** style defaults — change if needed:
> - Chain ID: `560048`
> - Drosera relay: `0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D`

---

## 1) Get the code

```bash
git clone https://github.com/R1ghTsS/vault-tvl-drop-trap.git
cd vault-tvl-drop-trap
forge build
```

Set environment you’ll reuse:
```bash
export RPC=http://127.0.0.1:8545        # or your private/public RPC
export PK=0xYOUR_PRIVATE_KEY            # deployer EOA
export DROSERA_ADDR=0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
export CHAIN_ID=560048
unset FOUNDRY_DRY_RUN                   # make sure broadcasts are enabled
```

---

## 2) Contracts

- `src/MockVault.sol` – minimal test vault exposing `setTotalAssets(uint256)` and `totalAssets()`.
- `src/VaultTVLDropTrap.sol` – **the trap**:
  - `collect()` encodes `{blockNumber, assets}`
  - `shouldRespond(bytes[] data)` finds **peak** in the window then compares with **current**
  - **edit before build:** `VAULT`, `DROP_THRESHOLD_BPS`, `MIN_ABSOLUTE_DROP`
- `src/VaultTVLResponse.sol` – sample response contract that emits:
  ```solidity
  event VaultDrop(string message);
  ```
  via `handleVaultDrop(string)`.

---

## 3) Deploy locally / on your network

### 3.1 Deploy a Mock Vault (for testing)

**Option A – forge create**
```bash
forge create src/MockVault.sol:MockVault \
  --rpc-url $RPC \
  --private-key $PK \
  --constructor-args 1000e18 \
  --broadcast --skip-simulation
```

**Option B – cast send**
```bash
BYTECODE=$(jq -r '.bytecode.object' out/MockVault.sol/MockVault.json)
ENCARGS=$(cast abi-encode "constructor(uint256)" 1000e18)
INITCODE=${BYTECODE}${ENCARGS#0x}

cast send --create $INITCODE --rpc-url $RPC --private-key $PK
```

Save the address:
```bash
cast receipt <TX_HASH> --rpc-url $RPC | grep -Ei 'contractAddress|to'
export VAULT=0x... # paste the MockVault address
```

Sanity check:
```bash
cast call $VAULT "totalAssets()(uint256)" --rpc-url $RPC
```

### 3.2 Deploy the Response contract

```bash
BYTECODE=$(jq -r '.bytecode.object' out/VaultTVLResponse.sol/VaultTVLResponse.json)
cast send --create $BYTECODE --rpc-url $RPC --private-key $PK
export RESP=$(cast receipt <TX_HASH> --rpc-url $RPC | awk '/contractAddress/{print $2}')
```

### 3.3 Configure & build the Trap

Edit constants in **`src/VaultTVLDropTrap.sol`**:
```solidity
address public constant VAULT = 0xYourVaultHere;
uint256 public constant DROP_THRESHOLD_BPS = 500; // 5%
uint256 public constant MIN_ABSOLUTE_DROP = 0;    // optional
```
Then:
```bash
forge build
```

### 3.4 Create `drosera.toml` and apply

`drosera.toml`:
```toml
ethereum_rpc    = "${RPC}"
drosera_rpc     = "https://relay.hoodi.drosera.io"
eth_chain_id    = ${CHAIN_ID}
drosera_address = "${DROSERA_ADDR}"

[traps]

[traps.vaulttvldrop]
path                    = "out/VaultTVLDropTrap.sol/VaultTVLDropTrap.json"
response_contract       = "${RESP}"
response_function       = "handleVaultDrop(string)"
cooldown_period_blocks  = 10
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size       = 10
private_trap            = true
whitelist               = ["0xYourEOAAllowed"]
```

> **TOML tip:** addresses must be quoted strings. Writing `response_contract = $RESP` (unquoted) will fail to parse.

Apply:
```bash
export DROSERA_PRIVATE_KEY=$PK
drosera apply --eth-rpc-url $RPC
# output prints a "Trap Config" address:
export TRAPCFG=0x... 
```

### 3.5 Run an Operator (CLI or Docker)

**Register & opt‑in (CLI):**
```bash
drosera-operator register \
  --eth-rpc-url $RPC \
  --eth-private-key <OPERATOR_PK> \
  --drosera-address $DROSERA_ADDR

drosera-operator optin \
  --eth-rpc-url $RPC \
  --eth-private-key <OPERATOR_PK> \
  --trap-config-address $TRAPCFG
```

**Docker Compose** (example `~/Drosera-Network/docker-compose.yaml`):
```yaml
services:
  drosera-operator:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-operator
    ports:
      - "31313:31313"   # P2P
      - "31314:31314"   # HTTP/server
    environment:
      - DRO__DB_FILE_PATH=/data/drosera.db
      - DRO__DROSERA_ADDRESS=${DROSERA_ADDR}
      - DRO__LISTEN_ADDRESS=0.0.0.0
      - DRO__DISABLE_DNR_CONFIRMATION=true
      - DRO__ETH__CHAIN_ID=${CHAIN_ID}
      - DRO__ETH__RPC_URL=${RPC}
      - DRO__ETH__PRIVATE_KEY=${OPERATOR_PK}
      - DRO__NETWORK__P2P_PORT=31313
      - DRO__NETWORK__EXTERNAL_P2P_ADDRESS=${VPS_IP}
      - DRO__SERVER__PORT=31314
      - RUST_LOG=info,drosera_operator=debug
    volumes:
      - drosera_data:/data
    restart: always
    command: node
volumes:
  drosera_data: {}
```
`.env` beside compose file:
```env
RPC=http://127.0.0.1:8545
OPERATOR_PK=0xYourOperatorKey
DROSERA_ADDR=0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
CHAIN_ID=560048
VPS_IP=$(curl -s ifconfig.me)
```

Run:
```bash
docker compose up -d && docker compose logs -f drosera-operator
```

You should see entries like:
```
ShouldRespond='true' trap_address=... block_number=...
Pending Transaction Hash: 0x...
Successfully submitted claim ...
```

---

## 4) Test the alert end‑to‑end

1. **Raise TVL** (optional):
   ```bash
   # either literal exponent or computed:
   cast send $VAULT "setTotalAssets(uint256)" 1200e18 \
     --rpc-url $RPC --private-key $PK
   # or: cast send $VAULT "setTotalAssets(uint256)" $(cast --to-wei "1200 ether") ...
   ```

2. **Drop TVL** below threshold:
   ```bash
   cast send $VAULT "setTotalAssets(uint256)" 700e18 \
     --rpc-url $RPC --private-key $PK
   ```

3. **Watch operator logs** – after a few blocks you should see `ShouldRespond='true'`
   and a submission transaction.

4. **Verify on‑chain** (see next section).

---

## 5) Read events & debug

Read `VaultDrop(string)` events from the response contract (**Foundry ≥1.3 uses the positional signature**):
```bash
LATEST=$(cast block-number --rpc-url $RPC)
FROM=$((LATEST-50))
cast logs --rpc-url $RPC --address $RESP --from-block $FROM --to-block $LATEST "VaultDrop(string)"
```

Manual sanity emit:
```bash
cast send $RESP "handleVaultDrop(string)" "TVL drop test" --rpc-url $RPC --private-key $PK
```

Other checks:
```bash
cast code $VAULT --rpc-url $RPC
cast code $RESP  --rpc-url $RPC
cast receipt 0x<submission_tx_hash> --rpc-url $RPC
```

---

## Troubleshooting

- **“Dry run enabled, not broadcasting transaction”** → `unset FOUNDRY_DRY_RUN` or use `--broadcast --skip-simulation`.
- **TOML parse error `unexpected character '$'`** → Quote variables: `response_contract = "${RESP}"`.
- **`cast logs` shows nothing** → Use the **positional** signature (`"VaultDrop(string)"`) and numeric block ranges.
- **Operator warns `InsufficientPeers`** → With a single operator you can still submit; ensure ports `31313/31314` are open to improve connectivity.

---

## License

MIT
