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

### 1. Create Lending Pools
The admin (`0x35f6e214676208fd20dCD93d19f10e909FF2Bb8e`) needs to create lending pools for each asset:

```bash
# Using forge script with admin private key
forge script script/lendingpool/DeployPositionsLendingPool.s.sol:CreateLendingPool \
  --sig "run(address,address)" \
  0xb1a80401e961cedb4ff66ce28a6335fae8355521 \
  <ASSET_ADDRESS> \
  --rpc-url $POLYGON_MAINNET_RPC_URL \
  --broadcast \
  --private-key <ADMIN_PRIVATE_KEY>
```

Assets to create pools for:
- WETH: `0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619`
- USDC: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`
- USDT: `0xc2132D05D31c914a87C6611C10748AEb04B58e8F`
- WBTC: `0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6`

### 2. Configure Price Feeds
The operator needs to set up Pyth price feed IDs for each asset in the PriceOracle contract.

### 3. Register Handlers with Entrypoint
The admin needs to register the handlers with the VaultsEntrypoint contract.

### 4. Contract Verification
Verify contracts on Polygonscan using:
```bash
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id 137 \
  --etherscan-api-key <POLYGONSCAN_API_KEY>
```

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
