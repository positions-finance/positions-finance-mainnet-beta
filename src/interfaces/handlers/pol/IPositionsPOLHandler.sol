//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPositionsPOLHandler.
 * @author Positions Team.
 * @notice Interface for the Positions <> Berachain's Proof of Liquidity integration.
 */
interface IPositionsPOLHandler {
    struct RewardVaultInfo {
        address stakingToken;
        address rewardToken;
    }

    struct PositionInfo {
        uint256 balance;
        uint256 unclaimedReward;
        uint256 rewardsPerTokenPaid;
    }

    event RelayerSet(address indexed newRelayer);
    event EntrypointSet(address indexed newEntrypoint);
    event RedeemBGTForBera(address indexed sender, uint256 tokenId, uint256 amount);
    event RewardVaultAdded(address indexed rewardVault, RewardVaultInfo rewardVaultInfo);
    event RewardVaultRemoved(address indexed rewardVault);

    error PositionsPOLHandler__NotEntryPoint();
    error PositionsPOLHandler__ArrayLengthMismatch();
    error PositionsPOLHandler__NotStakingToken();
    error PositionsPOLHandler__InsufficientBalance(uint256 tokenId, uint256 positionBalance, uint256 withdrawalAmount);
    error PositionsPOLHandler__NFTOwnershipVerificationFailed(address user, uint256 tokenId);
    error PositionsPOLHandler__RewardVaultDoesNotExist();

    function addRewardVaults(address[] calldata _rewardVaults, RewardVaultInfo[] calldata _rewardVaultInfos) external;
    function removeRewardVaults(address[] calldata _rewardVaults) external;
}
