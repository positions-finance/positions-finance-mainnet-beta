// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin-contracts-5.3.0/utils/structs/EnumerableSet.sol";

import {IHandler} from "../IHandler.sol";
import {IPositionsDataProvider} from "../../utils/IPositionsDataProvider.sol";

interface IPositionsInfraredVaultHandler is IHandler {
    struct PositionInfo {
        uint256 balance;
        EnumerableSet.AddressSet rewardTokens;
        mapping(address token => TokenReward tokenRewardInfo) tokenRewardInfo;
    }

    struct TokenReward {
        uint256 unclaimedReward;
        uint256 rewardsPerTokenPaid;
    }

    event EntrypointSet(address newEntrypoint);
    event ProofOfCollateralSet(address newProofOfCollateral);
    event OracleSet(address newOracle);
    event InfraredVaultAdded(address infraredVault, address stakingToken);
    event InfraredVaultRemoved(address infraredVault);
    event RelayerSet(address relayer);
    event OperatorSet(uint256 indexed tokenId, address indexed operator);

    error PositionsInfraredVaultHandler__InsufficientBalance(
        uint256 tokenId, uint256 positionBalance, uint256 withdrawalAmount
    );
    error PositionsInfraredVaultHandler__NotEntryPoint();
    error PositionsInfraredVaultHandler__UnsupportedToken();
    error PositionsInfraredVaultHandler__InfraredVaultDoesNotExist();
    error PositionsInfraredVaultHandler__NotStakingToken();
    error PositionsInfraredVaultHandler__NFTOwnershipVerificationFailed(address user, uint256 tokenId);

    function initialize(address _admin, address _upgrader, address _entryPoint, address _poc, address _oracle)
        external;
    function setEntrypoint(address _newEntryPoint) external;
    function setRelayer(address _newRelayer) external;
    function setOracle(address _newOracle) external;
    function addInfraredVaults(address[] calldata _infraredVaults, address[] calldata _stakingTokens) external;
    function removeInfraredVaults(address[] calldata _infraredVaults) external;
    function getReward(address[] calldata _infraredVaults, uint256 _tokenId, bytes32[] memory _proof, address _receiver)
        external;
    function getUpgraderRole() external pure returns (bytes32);
    function getEntryPoint() external view returns (address);
    function getRelayer() external view returns (address);
    function getOracle() external view returns (address);
    function getInfraredVaults() external view returns (address[] memory);
    function getInfraredVaultStakingToken(address _infraredVault) external view returns (address);
    function getEarned(address _infraredVault, address _rewardToken, uint256 _tokenId)
        external
        view
        returns (uint256);
    function getRewardPerToken(address _infraredVault, address _rewardToken) external view returns (uint256);
    function getStakingTokenToInfraredVaults(address _token) external view returns (address[] memory);
    function getPositionBalance(address _rewardVault, uint256 _tokenId) external view returns (uint256);
}
