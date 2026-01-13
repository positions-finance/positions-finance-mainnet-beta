# Polygon Mainnet Deployment

## Deployment Date
January 13, 2026

## Chain Information
- **Network**: Polygon Mainnet
- **Chain ID**: 137
- **RPC URL**: https://polygon-mainnet.g.alchemy.com/v2/...

---

## Summary of Changes

This deployment adapts the Positions Finance protocol from Berachain to Polygon mainnet. The core lending and Uniswap V3 position management functionality has been preserved, while Berachain-specific features have been removed.

### What Was Added

To enable Polygon mainnet deployment, we added chain ID 137 support across all helper configuration files. The new admin address (`0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e`) and operator address (`0x98Fd8A40528FC3BD92c6F231bEe0551295FeCeE4`) were configured in `VaultsEntrypointHelperConfig.sol`, `LendingPoolHelperConfig.sol`, `UniV3HelperConfig.sol`, `PositionsDataProviderHelperConfig.sol`, `HelperConfigLendingPool.s.sol`, and `DeployPriceOracle.s.sol`. External protocol addresses were added including the Pyth Oracle (`0xff1a0f4744e8582DF1aE09D5611b887B6a12925C`) and Uniswap V3 NonfungiblePositionManager (`0xC36442b4a4522E871399CD717aBDD847Ab11FE88`). Four ERC-20 token addresses were configured for lending pools: WETH (`0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619`), USDC (`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`), USDT (`0xc2132D05D31c914a87C6611C10748AEb04B58e8F`), and WBTC (`0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6`). The `.env` file was updated with `POLYGON_MAINNET_RPC_URL`. Additionally, deployment scripts were enhanced to accept contract addresses as parameters, enabling a cleaner deployment flow where dependent contracts can be deployed in sequence without modifying configuration files.

### What Was Removed

Several Berachain-specific contracts and features were removed from this branch as they have no equivalent on Polygon. The **Infrared integration** was removed, including `PositionsInfraredVaultHandler.sol` and its related interfaces (`IInfrared.sol`, `IInfraredVault.sol`, `IMultiRewards.sol`, `IPositionsInfraredVaultHandler.sol`) and deployment scripts. The **Proof of Liquidity (POL) handlers** were removed, including `PositionsPOLHandler.sol`, `PositionsBGTHandler.sol`, and all related interfaces (`IBGT.sol`, `IBerachainRewardsVault.sol`, `IBerachainRewardsVaultFactory.sol`, `IPOLErrors.sol`, `IPositionsPOLHandler.sol`, `IStakingRewards.sol`) and deployment scripts. The **Loops protocol integration** was removed, including `PositionsLoops.sol` and its interfaces (`IIslandRouter.sol`, `IKodiakIsland.sol`, `ISwapRouter.sol`, `IWETH.sol`) and deployment scripts. All corresponding test files were also removed.

### What Remains

The core protocol functionality is fully operational on Polygon: the **PositionsVaultsEntrypoint** for vault management, **PositionsLendingPool** for lending/borrowing operations, **PositionsLendingPoolHandler** for handling lending pool interactions through the entrypoint, **PositionsUniV3Handler** for managing Uniswap V3 positions, **PriceOracle** using Pyth for asset pricing, and **PositionsDataProvider** for querying protocol state.

---

## Deployed Contract Addresses

### Core Contracts

| Contract | Proxy Address | Implementation Address |
|----------|---------------|------------------------|
| **PriceOracle** | `0x81a6169cb92ddcf41a264333b59a777a5351a1d1` | `0x33d92194d102b17d38bfea98c3c4160b3787abb1` |
| **PositionsVaultsEntrypoint** | `0x520986accba2115a9b63231ca062432e7926ec4a` | `0x7c2727f826dd110d7a8a2ce19c7b4d1fd9d66548` |
| **PositionsLendingPool** | `0xb1a80401e961cedb4ff66ce28a6335fae8355521` | `0x65a8bed5d6a27739399a9f58c6305eb466b8d197` |
| **PositionsLendingPoolHandler** | `0x5558400e4e160b1e34090bd13bcbb9b6ecc530f4` | `0xe11fb0d76836f243838dce410333bb15de868ec0` |
| **PositionsUniV3Handler** | `0x426e583135d5ce0e4df631674c05f57218885054` | `0x5bb0844984a92761b67c6b5b6efecc6e6ee4c5b5` |
| **PositionsDataProvider** | `0x2e89f4b127b1db8d5c23328d09f2ac6ff0c5484e` | N/A (not upgradeable) |

### Supporting Contracts

| Contract | Address |
|----------|---------|
| **PythUtils** | `0x1cafac6790a823616b3fc371578bfc315cae3989` |

---

## Role Addresses

| Role | Address |
|------|---------|
| **Admin** | `0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e` |
| **Upgrader** | `0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e` |
| **Operator/Relayer** | `0x98Fd8A40528FC3BD92c6F231bEe0551295FeCeE4` |

---

## External Contract Addresses (Polygon Mainnet)

| Contract | Address |
|----------|---------|
| **Pyth Oracle** | `0xff1a0f4744e8582DF1aE09D5611b887B6a12925C` |
| **Uniswap V3 NonfungiblePositionManager** | `0xC36442b4a4522E871399CD717aBDD847Ab11FE88` |

---

## Supported Assets

| Asset | Address |
|-------|---------|
| **WETH** | `0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619` |
| **USDC** | `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174` |
| **USDT** | `0xc2132D05D31c914a87C6611C10748AEb04B58e8F` |
| **WBTC** | `0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6` |

---

## Post-Deployment Actions Required

The following actions must be performed by the **Admin** (`0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e`) using the admin's private key.

### 1. Register Handlers with Entrypoint

The admin must register both handlers with the VaultsEntrypoint contract using the `addHandler` function:

```bash
# Register LendingPoolHandler
cast send 0x520986accba2115a9b63231ca062432e7926ec4a \
  "addHandler(address)" \
  0x5558400e4e160b1e34090bd13bcbb9b6ecc530f4 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>

# Register UniV3Handler
cast send 0x520986accba2115a9b63231ca062432e7926ec4a \
  "addHandler(address)" \
  0x426e583135d5ce0e4df631674c05f57218885054 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>
```

### 2. Configure Price Feeds in PriceOracle

The admin must set Pyth price feed IDs for each supported asset using `setPythPriceId`. You can find Pyth price feed IDs at https://pyth.network/developers/price-feed-ids

```bash
# Set WETH price feed
cast send 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "setPythPriceId(address,bytes32)" \
  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 \
  0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>

# Set USDC price feed
cast send 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "setPythPriceId(address,bytes32)" \
  0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 \
  0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>

# Set USDT price feed
cast send 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "setPythPriceId(address,bytes32)" \
  0xc2132D05D31c914a87C6611C10748AEb04B58e8F \
  0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>

# Set WBTC price feed
cast send 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "setPythPriceId(address,bytes32)" \
  0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6 \
  0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>
```

**Pyth Price Feed IDs for Polygon Mainnet:**
| Asset | Pyth Price Feed ID |
|-------|-------------------|
| ETH/USD | `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` |
| USDC/USD | `0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a` |
| USDT/USD | `0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b` |
| BTC/USD | `0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33` |

### 3. Set Staleness Thresholds (Optional but Recommended)

Set staleness thresholds for each asset to define how old price data can be before it's considered stale:

```bash
# Set staleness threshold to 1 hour (3600 seconds) for each asset
cast send 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "setStalenessThreshold(address,uint256)" \
  <ASSET_ADDRESS> \
  3600 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>
```

### 4. Create Lending Pools

The admin must create lending pools for each supported asset:

```bash
# Using forge script
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:CreateLendingPool \
  --sig "run(address,address)" \
  0xb1a80401e961cedb4ff66ce28a6335fae8355521 \
  <ASSET_ADDRESS> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key <ADMIN_PRIVATE_KEY>

# Or using cast directly
cast send 0xb1a80401e961cedb4ff66ce28a6335fae8355521 \
  "createLendingPool(address,(uint256,uint256,uint256,uint256))" \
  <ASSET_ADDRESS> \
  "(0,675000000000000000000000000,750000000000000000000000000,750000000000000000000000000)" \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --private-key <ADMIN_PRIVATE_KEY>
```

**Assets to create pools for:**
| Asset | Address | Command |
|-------|---------|---------|
| WETH | `0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619` | Replace `<ASSET_ADDRESS>` above |
| USDC | `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174` | Replace `<ASSET_ADDRESS>` above |
| USDT | `0xc2132D05D31c914a87C6611C10748AEb04B58e8F` | Replace `<ASSET_ADDRESS>` above |
| WBTC | `0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6` | Replace `<ASSET_ADDRESS>` above |

**Interest Rate Model Parameters:**
- `baseRate`: 0
- `slope1`: 675000000000000000000000000 (67.5%)
- `slope2`: 750000000000000000000000000 (75%)
- `optimalUtilization`: 750000000000000000000000000 (75%)

### 5. Contract Verification on Polygonscan

Verify all contracts for transparency:

```bash
# Get a Polygonscan API key from https://polygonscan.com/apis
export POLYGONSCAN_API_KEY=your_api_key_here

# Verify PriceOracle implementation
forge verify-contract 0x33d92194d102b17d38bfea98c3c4160b3787abb1 \
  src/oracle/PriceOracle.sol:PriceOracle \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY

# Verify PositionsVaultsEntrypoint implementation
forge verify-contract 0x7c2727f826dd110d7a8a2ce19c7b4d1fd9d66548 \
  src/entryPoint/PositionsVaultsEntrypoint.sol:PositionsVaultsEntrypoint \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY

# Verify PositionsLendingPool implementation
forge verify-contract 0x65a8bed5d6a27739399a9f58c6305eb466b8d197 \
  src/protocols/lendingPool/PositionsLendingPool.sol:PositionsLendingPool \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY

# Verify PositionsLendingPoolHandler implementation
forge verify-contract 0xe11fb0d76836f243838dce410333bb15de868ec0 \
  src/handlers/lendingPool/PositionsLendingPoolHandler.sol:PositionsLendingPoolHandler \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY

# Verify PositionsUniV3Handler implementation
forge verify-contract 0x5bb0844984a92761b67c6b5b6efecc6e6ee4c5b5 \
  src/handlers/uniV3/PositionsUniV3Handler.sol:PositionsUniV3Handler \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY

# Verify PositionsDataProvider
forge verify-contract 0x2e89f4b127b1db8d5c23328d09f2ac6ff0c5484e \
  src/utils/PositionsDataProvider.sol:PositionsDataProvider \
  --chain-id 137 \
  --etherscan-api-key $POLYGONSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address)" 0x520986accba2115a9b63231ca062432e7926ec4a 0xb1a80401e961cedb4ff66ce28a6335fae8355521)
```

### 6. Verify Deployment (Sanity Checks)

After completing all setup steps, verify the deployment:

```bash
# Check handlers are registered
cast call 0x520986accba2115a9b63231ca062432e7926ec4a \
  "getSupportedHandlers()(address[])" \
  --rpc-url $POLYGON_MAINNET_RPC_URL

# Check price feed is set for WETH
cast call 0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  "getPrice(address)(uint256)" \
  0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619 \
  --rpc-url $POLYGON_MAINNET_RPC_URL

# Check admin role on entrypoint
cast call 0x520986accba2115a9b63231ca062432e7926ec4a \
  "hasRole(bytes32,address)(bool)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e \
  --rpc-url $POLYGON_MAINNET_RPC_URL
```

---

## Full Deployment Instructions (From Scratch)

If you need to redeploy all contracts from scratch, follow these steps in order. Each step depends on the previous one.

### Prerequisites

1. **Set up environment variables** in `.env`:
```bash
POLYGON_MAINNET_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=your_deployer_private_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
```

2. **Load environment variables**:
```bash
source .env
```

3. **Ensure deployer has sufficient MATIC** (~25 MATIC recommended for all deployments)

4. **Build contracts**:
```bash
forge build
```

### Step 1: Deploy PriceOracle

The PriceOracle is deployed first as it has no dependencies on other contracts.

```bash
forge script script/oracle/DeployPriceOracle.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the proxy address (e.g., `0x81a6169cb92ddcf41a264333b59a777a5351a1d1`)

**What this deploys:**
- PriceOracle implementation contract
- ERC1967Proxy pointing to the implementation
- Initializes with admin, upgrader, operator, and Pyth oracle address

### Step 2: Deploy PositionsVaultsEntrypoint

The entrypoint is the main contract users interact with.

```bash
forge script script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the proxy address (e.g., `0x520986accba2115a9b63231ca062432e7926ec4a`)

**What this deploys:**
- PositionsVaultsEntrypoint implementation contract
- ERC1967Proxy pointing to the implementation
- Initializes with admin, upgrader, and relayer roles

### Step 3: Deploy PositionsLendingPool

The lending pool requires the oracle address from Step 1.

```bash
# Replace <ORACLE_PROXY> with the proxy address from Step 1
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:DeployPositionsLendingPool \
  --sig "run(address)" \
  <ORACLE_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Example with actual address:**
```bash
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:DeployPositionsLendingPool \
  --sig "run(address)" \
  0x81a6169cb92ddcf41a264333b59a777a5351a1d1 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the proxy address (e.g., `0xb1a80401e961cedb4ff66ce28a6335fae8355521`)

**What this deploys:**
- PositionsLendingPool implementation contract
- ERC1967Proxy pointing to the implementation
- Initializes with admin, relayer, oracle, and reserve factor

### Step 4: Deploy PositionsLendingPoolHandler

The handler requires both the entrypoint (Step 2) and lending pool (Step 3) addresses.

```bash
# Replace <ENTRYPOINT_PROXY> and <LENDING_POOL_PROXY> with addresses from Steps 2 and 3
forge script script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol:DeployPositionsLendingPoolHandler \
  --sig "run(address,address)" \
  <ENTRYPOINT_PROXY> \
  <LENDING_POOL_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Example with actual addresses:**
```bash
forge script script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol:DeployPositionsLendingPoolHandler \
  --sig "run(address,address)" \
  0x520986accba2115a9b63231ca062432e7926ec4a \
  0xb1a80401e961cedb4ff66ce28a6335fae8355521 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the proxy address (e.g., `0x5558400e4e160b1e34090bd13bcbb9b6ecc530f4`)

**What this deploys:**
- PositionsLendingPoolHandler implementation contract
- ERC1967Proxy pointing to the implementation
- Initializes with entrypoint, lending pool, admin, and upgrader

### Step 5: Deploy PositionsUniV3Handler

The UniV3 handler reads its configuration from the helper config.

```bash
forge script script/handlers/uniV3/DeployPositionsUniV3Handler.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the proxy address (e.g., `0x426e583135d5ce0e4df631674c05f57218885054`)

**What this deploys:**
- PositionsUniV3Handler implementation contract
- ERC1967Proxy pointing to the implementation
- Initializes with relayer, Uniswap V3 NFT manager, admin, and upgrader

### Step 6: Deploy PositionsDataProvider

The data provider requires both the entrypoint (Step 2) and lending pool (Step 3) addresses.

```bash
# Replace <ENTRYPOINT_PROXY> and <LENDING_POOL_PROXY> with addresses from Steps 2 and 3
forge script script/utils/DeployPositionsDataProvider.sol:DeployPositionsDataProvider \
  --sig "run(address,address)" \
  <ENTRYPOINT_PROXY> \
  <LENDING_POOL_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Example with actual addresses:**
```bash
forge script script/utils/DeployPositionsDataProvider.sol:DeployPositionsDataProvider \
  --sig "run(address,address)" \
  0x520986accba2115a9b63231ca062432e7926ec4a \
  0xb1a80401e961cedb4ff66ce28a6335fae8355521 \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Expected output:** Note the contract address (e.g., `0x2e89f4b127b1db8d5c23328d09f2ac6ff0c5484e`)

**What this deploys:**
- PositionsDataProvider contract (not upgradeable)
- Initialized with entrypoint and lending pool addresses

### Deployment Summary

After completing all steps, you should have deployed:

| Order | Contract | Depends On |
|-------|----------|------------|
| 1 | PriceOracle | None |
| 2 | PositionsVaultsEntrypoint | None |
| 3 | PositionsLendingPool | PriceOracle (Step 1) |
| 4 | PositionsLendingPoolHandler | Entrypoint (Step 2), LendingPool (Step 3) |
| 5 | PositionsUniV3Handler | None (reads from config) |
| 6 | PositionsDataProvider | Entrypoint (Step 2), LendingPool (Step 3) |

### Quick Deploy Script

For convenience, here's a complete script to deploy all contracts in sequence:

```bash
#!/bin/bash
set -e

source .env

echo "=== Step 1: Deploying PriceOracle ==="
forge script script/oracle/DeployPriceOracle.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "Enter the PriceOracle proxy address:"
read ORACLE_PROXY

echo "=== Step 2: Deploying PositionsVaultsEntrypoint ==="
forge script script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "Enter the PositionsVaultsEntrypoint proxy address:"
read ENTRYPOINT_PROXY

echo "=== Step 3: Deploying PositionsLendingPool ==="
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:DeployPositionsLendingPool \
  --sig "run(address)" \
  $ORACLE_PROXY \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "Enter the PositionsLendingPool proxy address:"
read LENDING_POOL_PROXY

echo "=== Step 4: Deploying PositionsLendingPoolHandler ==="
forge script script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol:DeployPositionsLendingPoolHandler \
  --sig "run(address,address)" \
  $ENTRYPOINT_PROXY \
  $LENDING_POOL_PROXY \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "=== Step 5: Deploying PositionsUniV3Handler ==="
forge script script/handlers/uniV3/DeployPositionsUniV3Handler.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "=== Step 6: Deploying PositionsDataProvider ==="
forge script script/utils/DeployPositionsDataProvider.sol:DeployPositionsDataProvider \
  --sig "run(address,address)" \
  $ENTRYPOINT_PROXY \
  $LENDING_POOL_PROXY \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

echo "=== Deployment Complete ==="
echo "Oracle Proxy: $ORACLE_PROXY"
echo "Entrypoint Proxy: $ENTRYPOINT_PROXY"
echo "LendingPool Proxy: $LENDING_POOL_PROXY"
```

Save this as `deploy-polygon.sh`, make it executable (`chmod +x deploy-polygon.sh`), and run it.

---

## Configuration Changes Made for Polygon Deployment

### Files Modified

#### 1. `script/utils/ChainIds.sol`
- Added `POLYGON_MAINNET_CHAIN_ID = 137` constant

#### 2. `script/vaultsEntrypoint/VaultsEntrypointHelperConfig.sol`
- Added `_getPolygonMainnetConfig()` function with admin, upgrader, and relayer addresses

#### 3. `script/handlers/lendingPool/LendingPoolHelperConfig.sol`
- Added `_getPolygonMainnetConfig()` function with admin and upgrader addresses

#### 4. `script/handlers/uniV3/UniV3HelperConfig.sol`
- Added `POLYGON_MAINNET_UNIV3_NFT_POSITION_MANAGER` constant
- Added `_getPolygonMainnetConfig()` function with full config

#### 5. `script/utils/PositionsDataProviderHelperConfig.sol`
- Added chain ID check for `POLYGON_MAINNET_CHAIN_ID`
- Added `_getPolygonMainnetConfig()` function

#### 6. `script/lendingpool/HelperConfig.s.sol`
- Added `POLYGON_MAINNET_CHAIN_ID = 137` constant
- Added `getPolygonMainnetConfig()` function with asset addresses (WETH, USDC, USDT, WBTC)

#### 7. `script/oracle/DeployPriceOracle.s.sol`
- Updated admin, upgrader, operator addresses for Polygon mainnet

#### 8. `script/poc/HelperConfig.s.sol`
- Added Polygon mainnet configuration

#### 9. `.env`
- Added `POLYGON_MAINNET_RPC_URL`

### Deployment Script Enhancements

#### `script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol`
- Added parameterized `run(address entrypoint, address lendingPool)` function
- Added `UpgradePositionsLendingPoolHandler` contract

#### `script/utils/DeployPositionsDataProvider.sol`
- Added parameterized `run(address entrypoint, address lendingPool)` function

#### `script/lendingpool/DeployPositionsLendingPool.s.sol`
- Added parameterized `run(address oracle)` function
- Added `UpgradePositionsLendingPool` contract
- Added `CreateLendingPool` contract for creating asset pools

---

## Contracts NOT Deployed on Polygon (Removed from Main Branch)

The following contracts/features are specific to Berachain and have been removed from this branch:

### Handlers
| Contract | Reason |
|----------|--------|
| `PositionsInfraredVaultHandler` | Infrared is Berachain-specific |
| `PositionsPOLHandler` | POL (Proof of Liquidity) is Berachain-specific |
| `PositionsBGTHandler` | BGT is Berachain's native token |

### Interfaces
| Interface | Reason |
|-----------|--------|
| `IInfrared.sol` | Infrared protocol interface (Berachain) |
| `IInfraredVault.sol` | Infrared vault interface (Berachain) |
| `IMultiRewards.sol` | Multi-rewards interface (Berachain) |
| `IPositionsInfraredVaultHandler.sol` | Handler interface (Berachain) |
| `IBGT.sol` | BGT token interface (Berachain) |
| `IBerachainRewardsVault.sol` | Rewards vault interface (Berachain) |
| `IBerachainRewardsVaultFactory.sol` | Factory interface (Berachain) |
| `IPOLErrors.sol` | POL error definitions (Berachain) |
| `IPositionsPOLHandler.sol` | POL handler interface (Berachain) |
| `IStakingRewards.sol` | Staking rewards interface (Berachain) |

### Protocols
| Contract | Reason |
|----------|--------|
| `PositionsLoops.sol` | Loops protocol (Berachain-specific) |

### Protocol Interfaces (Loops)
| Interface | Reason |
|-----------|--------|
| `IIslandRouter.sol` | Kodiak Island router (Berachain) |
| `IKodiakIsland.sol` | Kodiak Island interface (Berachain) |
| `ISwapRouter.sol` | Swap router (Berachain) |
| `IWETH.sol` | WETH interface (Berachain variant) |

### Deployment Scripts
| Script | Reason |
|--------|--------|
| `DeployPositionsInfraredVaultHandler.s.sol` | Infrared (Berachain) |
| `InfraredVaultHandlerHelperConfig.sol` | Infrared config (Berachain) |
| `DeployPOLHandler.s.sol` | POL handler (Berachain) |
| `POLHelperConfig.sol` | POL config (Berachain) |
| `DeployPositionsLoops.s.sol` | Loops (Berachain) |
| `PositionsLoopsHelperConfig.sol` | Loops config (Berachain) |

### Tests
| Test | Reason |
|------|--------|
| `PositionsInfraredHandler.t.sol` | Infrared tests (Berachain) |
| `PositionsPOLHandler.t.sol` | POL tests (Berachain) |
| `PositionsLoopsTest.t.sol` | Loops tests (Berachain) |

---

## Deployment Commands Reference

```bash
# 1. Deploy PriceOracle
forge script script/oracle/DeployPriceOracle.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

# 2. Deploy VaultsEntrypoint
forge script script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

# 3. Deploy LendingPool (pass oracle proxy address)
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:DeployPositionsLendingPool \
  --sig "run(address)" <ORACLE_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

# 4. Deploy LendingPoolHandler (pass entrypoint and lendingPool proxy addresses)
forge script script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol:DeployPositionsLendingPoolHandler \
  --sig "run(address,address)" <ENTRYPOINT_PROXY> <LENDING_POOL_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

# 5. Deploy UniV3Handler
forge script script/handlers/uniV3/DeployPositionsUniV3Handler.s.sol \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY

# 6. Deploy DataProvider (pass entrypoint and lendingPool proxy addresses)
forge script script/utils/DeployPositionsDataProvider.sol:DeployPositionsDataProvider \
  --sig "run(address,address)" <ENTRYPOINT_PROXY> <LENDING_POOL_PROXY> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
```

---

## Gas Costs Summary

| Contract | Estimated Gas | Actual Cost (MATIC) |
|----------|---------------|---------------------|
| PriceOracle | ~2.9M | ~3.18 |
| VaultsEntrypoint | ~3.3M | ~3.64 |
| LendingPool | ~4.4M | ~5.02 |
| LendingPoolHandler | ~2.9M | ~3.27 |
| UniV3Handler | ~3.3M | ~3.97 |
| DataProvider | ~0.55M | ~0.67 |
| **Total** | ~17.35M | ~19.75 |

---

## Polygonscan Verification

After deployment, verify contracts at:
- https://polygonscan.com/address/<CONTRACT_ADDRESS>

API Key required in `.env`:
```
POLYGONSCAN_API_KEY=your_api_key_here
```
