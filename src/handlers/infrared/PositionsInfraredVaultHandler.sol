// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin-contracts-5.3.0/token/ERC721/IERC721.sol";

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin-contracts-5.3.0/utils/structs/EnumerableSet.sol";

import {IPositionsInfraredVaultHandler} from "../../interfaces/handlers/infrared/IPositionsInfraredVaultHandler.sol";
import {IInfraredVault} from "../../interfaces/handlers/infrared/IInfraredVault.sol";
import {IMultiRewards} from "../../interfaces/handlers/infrared/IMultiRewards.sol";
import {IPriceOracle} from "../../interfaces/oracle/IPriceOracle.sol";
import {IPositionsDataProvider} from "../../interfaces/utils/IPositionsDataProvider.sol";
import {IPositionsVaultsEntrypoint} from "../../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IPositionsRelayer} from "./../../interfaces/poc/IPositionsRelayer.sol";

import {Utils} from "../../utils/Utils.sol";
import {UserVaultBalance} from "../../utils/PositionsDataProvider.sol";

/// @title PositionsInfraredVaultHandler.
/// @author Positions Team.
/// @notice Handler to track and manage deposits and rewards on Infrared reward vaults.
contract PositionsInfraredVaultHandler is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    IPositionsInfraredVaultHandler
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The upgrader role can upgrade the proxy to a new implementation.
    bytes32 private constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice The positions vaults entry point contract address.
    address private s_entryPoint;
    /// @dev The price oracle to fetch token prices from.
    address private s_oracle;
    /// @dev The relayer address.
    address private s_relayer;
    /// @dev A set of supported infrared vaults.
    EnumerableSet.AddressSet private s_infraredVaults;
    /// @notice Mapping to store the staking token associated with each supported infrared vault.
    mapping(address => address) private s_vaultStakingToken;
    /// @dev Utility mapping to track infrared vaults per staking token.
    mapping(address token => EnumerableSet.AddressSet infraredVaults) private s_stakingTokenToInfraredVaults;
    /// @dev Mapping to track user deposits in infrared vaults.
    mapping(address infraredVault => mapping(uint256 tokenId => PositionInfo)) private s_positions;

    /// @notice Initializes the contract.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address which receives the upgrader role.
    /// @param _entryPoint The positions vaults entry point contract address.
    /// @param _oracle The oracle contract address.
    function initialize(address _admin, address _upgrader, address _entryPoint, address _relayer, address _oracle)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);

        s_entryPoint = _entryPoint;
        s_relayer = _relayer;
        s_oracle = _oracle;
    }

    /// @notice Allows the admin to set the new entry point contract address.
    /// @param _newEntryPoint The new entry point contract address.
    function setEntrypoint(address _newEntryPoint) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_newEntryPoint);

        s_entryPoint = _newEntryPoint;

        emit EntrypointSet(_newEntryPoint);
    }

    /// @notice Allows the admin to set the new relayer contract address.
    /// @param _newRelayer The new relayer contract address.
    function setRelayer(address _newRelayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_newRelayer);

        s_relayer = _newRelayer;

        emit RelayerSet(_newRelayer);
    }

    /// @notice Allows the admin to set the new oracle contract address.
    /// @param _newOracle The new oracle contract address.
    function setOracle(address _newOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.requireNotAddressZero(_newOracle);

        s_oracle = _newOracle;

        emit OracleSet(_newOracle);
    }

    /// @notice Admin-only function to support new infrared vaults.
    /// @param _infraredVaults The infrared vault addresses.
    /// @param _stakingTokens The infrared vault staking tokens.
    function addInfraredVaults(address[] calldata _infraredVaults, address[] calldata _stakingTokens)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 length = _infraredVaults.length;
        Utils.requireLengthsMatch(length, _stakingTokens.length);

        for (uint256 i; i < length; ++i) {
            s_infraredVaults.add(_infraredVaults[i]);
            s_stakingTokenToInfraredVaults[_stakingTokens[i]].add(_infraredVaults[i]);
            s_vaultStakingToken[_infraredVaults[i]] = _stakingTokens[i];

            emit InfraredVaultAdded(_infraredVaults[i], _stakingTokens[i]);
        }
    }

    /// @notice Admin-only function to remove supported infrared vaults.
    /// @param _infraredVaults The infrared vault addresses.
    function removeInfraredVaults(address[] calldata _infraredVaults) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = _infraredVaults.length;

        for (uint256 i; i < length; ++i) {
            s_infraredVaults.remove(_infraredVaults[i]);
            s_stakingTokenToInfraredVaults[s_vaultStakingToken[_infraredVaults[i]]].remove(_infraredVaults[i]);
            delete s_vaultStakingToken[_infraredVaults[i]];

            emit InfraredVaultRemoved(_infraredVaults[i]);
        }
    }

    /// @notice Deposits a user's tokens into the infrared vault. Called by the entry point contract.
    /// @param _token The token address.
    /// @param _amount The amount of tokens to deposit.
    /// @param _tokenId The user's Nft token Id.
    /// @param _additionalData The additional bytes data to be decoded into infrared vault address.
    function deposit(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData) external {
        address infraredVault = abi.decode(_additionalData, (address));
        address stakingToken = s_vaultStakingToken[infraredVault];

        _requireCallerIsEntryPoint();
        _checkIfInfraredVaultExists(infraredVault);
        _requireIsStakingToken(_token, stakingToken);

        _updateReward(infraredVault, _tokenId);
        s_positions[infraredVault][_tokenId].balance += _amount;

        IERC20(stakingToken).approve(infraredVault, _amount);
        IInfraredVault(infraredVault).stake(_amount);
    }

    /// @notice Queues tokens for withdrawal from an infrared vault.
    /// @param _token The token address.
    /// @param _amount The amount of token to withdraw.
    /// @param _tokenId The user's Nft token Id.
    /// @param _additionalData The additional bytes data to be decoded into reward vault address.
    function queueWithdraw(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData)
        external
    {
        _requireCallerIsEntryPoint();

        address infraredVault = abi.decode(_additionalData, (address));
        address stakingToken = s_vaultStakingToken[infraredVault];

        _requireCallerIsEntryPoint();
        _checkIfInfraredVaultExists(infraredVault);
        _requireIsStakingToken(_token, stakingToken);

        uint256 positionBalance = s_positions[infraredVault][_tokenId].balance;
        if (positionBalance < _amount) {
            revert PositionsInfraredVaultHandler__InsufficientBalance(_tokenId, positionBalance, _amount);
        }

        _updateReward(infraredVault, _tokenId);
    }

    /// @notice Withdraw tokens from infrared vault.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    /// @param _to The address to direct the withdrawn tokens to.
    /// @return The token address.
    /// @return The amount of tokens withdrawn.
    function completeWithdraw(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        address _to,
        bytes calldata /*_additionalData*/
    ) external returns (address, uint256) {
        _requireCallerIsEntryPoint();

        address infraredVault = address(uint160(_withdrawData.poolOrVault));
        address stakingToken = s_vaultStakingToken[infraredVault];

        _requireCallerIsEntryPoint();
        _checkIfInfraredVaultExists(infraredVault);

        _updateReward(infraredVault, _withdrawData.tokenId);

        IInfraredVault(infraredVault).withdraw(_withdrawData.amount);
        IERC20(stakingToken).safeTransfer(_to, _withdrawData.amount);

        return (stakingToken, _withdrawData.amount);
    }

    /// @notice Liquidates a position.
    /// @param _token The token address.
    /// @param _amount The token amount to liquidate.
    /// @param _tokenId The Nft tokenId.
    /// @param _additionalData The additional bytes data to be decoded into the reward vault address.
    function liquidate(
        address _token,
        uint256 _amount,
        uint256 _tokenId,
        address, /* _liquidator */
        bytes calldata _additionalData
    ) external {
        _requireCallerIsEntryPoint();

        address infraredVault = abi.decode(_additionalData, (address));
        _checkIfInfraredVaultExists(infraredVault);
        _requireIsStakingToken(_token, s_vaultStakingToken[infraredVault]);

        uint256 positionBalance = s_positions[infraredVault][_tokenId].balance;
        if (positionBalance < _amount) {
            revert PositionsInfraredVaultHandler__InsufficientBalance(_tokenId, positionBalance, _amount);
        }

        _updateReward(infraredVault, _tokenId);

        s_positions[infraredVault][_tokenId].balance -= _amount;
    }

    /// @notice Complete a liquidation and withdraw funds.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    /// @param _additionalData The additional bytes data to be decoded into the reward vault address.
    function completeLiquidation(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        bytes calldata _additionalData
    ) external returns (address, uint256) {
        _requireCallerIsEntryPoint();

        address infraredVault = abi.decode(_additionalData, (address));
        _checkIfInfraredVaultExists(infraredVault);

        _updateReward(infraredVault, _withdrawData.tokenId);

        IInfraredVault(infraredVault).withdraw(_withdrawData.amount);
        IERC20(s_vaultStakingToken[infraredVault]).safeTransfer(_withdrawData.to, _withdrawData.amount);

        return (s_vaultStakingToken[infraredVault], _withdrawData.amount);
    }

    /// @notice Callback into the handler once a withdrawal request is accepted.
    /// @param _withdrawalData The withdrawal data.
    function withdrawalRequestAccepted(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawalData) external {
        _requireCallerIsEntryPoint();

        s_positions[address(uint160(_withdrawalData.poolOrVault))][_withdrawalData.tokenId].balance -=
            _withdrawalData.amount;
    }

    /// @notice Collect rewards from infrared vaults.
    /// @param _infraredVaults The infrared vault addresses.
    /// @param _tokenId The user's nft tokenId.
    function getReward(address[] calldata _infraredVaults, uint256 _tokenId, bytes32[] memory _proof, address _receiver)
        external
    {
        Utils.requireNotAddressZero(_receiver);
        _validateNFTOwnership(_tokenId, _proof);

        for (uint256 i; i < _infraredVaults.length; ++i) {
            if (!s_infraredVaults.contains(_infraredVaults[i])) {
                continue;
            }

            PositionInfo storage position = s_positions[_infraredVaults[i]][_tokenId];
            address[] memory rewardTokens = position.rewardTokens.values();

            for (uint256 j; j < rewardTokens.length; ++j) {
                uint256 earnedAmount = getEarned(_infraredVaults[i], rewardTokens[j], _tokenId);

                position.tokenRewardInfo[rewardTokens[j]].unclaimedReward = 0;
                position.tokenRewardInfo[rewardTokens[j]].rewardsPerTokenPaid =
                    getRewardPerToken(_infraredVaults[i], rewardTokens[j]);

                if (IERC20(rewardTokens[j]).balanceOf(address(this)) < earnedAmount) {
                    IMultiRewards(_infraredVaults[i]).getReward();
                }
                IERC20(rewardTokens[j]).safeTransfer(_receiver, earnedAmount);
            }
        }
    }

    function _requireCallerIsEntryPoint() internal view {
        if (msg.sender != s_entryPoint) revert PositionsInfraredVaultHandler__NotEntryPoint();
    }

    function _checkIfInfraredVaultExists(address _rewardVault) internal view {
        if (!s_infraredVaults.contains(_rewardVault)) {
            revert PositionsInfraredVaultHandler__InfraredVaultDoesNotExist();
        }
    }

    function _validateNFTOwnership(uint256 _tokenId, bytes32[] memory _proof) internal view {
        if (!IPositionsRelayer(s_relayer).verifyNFTOwnership(msg.sender, _tokenId, _proof)) {
            revert PositionsInfraredVaultHandler__NFTOwnershipVerificationFailed(msg.sender, _tokenId);
        }
    }

    function _requireIsStakingToken(address _token, address _stakingToken) internal pure {
        if (_token != _stakingToken) revert PositionsInfraredVaultHandler__NotStakingToken();
    }

    function _updateReward(address _infraredVault, uint256 _tokenId) internal {
        address[] memory rewardTokens = IInfraredVault(_infraredVault).getAllRewardTokens();
        uint256 length = rewardTokens.length;
        PositionInfo storage position = s_positions[_infraredVault][_tokenId];

        for (uint256 i; i < length; ++i) {
            uint256 rewardPerToken = getRewardPerToken(_infraredVault, rewardTokens[i]);

            if (!position.rewardTokens.contains(rewardTokens[i])) {
                position.rewardTokens.add(rewardTokens[i]);
            }

            (
                position.tokenRewardInfo[rewardTokens[i]].unclaimedReward,
                position.tokenRewardInfo[rewardTokens[i]].rewardsPerTokenPaid
            ) = (getEarned(_infraredVault, rewardTokens[i], _tokenId), rewardPerToken);
        }
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets the upgrader role Id.
    /// @return The upgrader role Id.
    function getUpgraderRole() external pure returns (bytes32) {
        return UPGRADER_ROLE;
    }

    /// @notice Gets the entry point contract address.
    /// @return The entry point contract address.
    function getEntryPoint() external view returns (address) {
        return s_entryPoint;
    }

    /// @notice Gets the relayer contract address.
    /// @return The relayer contract address.
    function getRelayer() external view returns (address) {
        return s_relayer;
    }

    /// @notice Gets the oracle contract address.
    /// @return The oracle contract address.
    function getOracle() external view returns (address) {
        return s_oracle;
    }

    /// @notice Gets a set of supported infrared vaults.
    /// @return An array of supported infrared vault addresses.
    function getInfraredVaults() external view returns (address[] memory) {
        return s_infraredVaults.values();
    }

    /// @notice Gets the staking token address for an infrared vault.
    /// @param _infraredVault The infrared vault address.
    /// @return The staking token.
    function getInfraredVaultStakingToken(address _infraredVault) external view returns (address) {
        return s_vaultStakingToken[_infraredVault];
    }

    /// @notice Gets the total rewards a user earned from an infrared vault.
    /// @param _infraredVault The infrared vault address.
    /// @param _rewardToken The reward token address.
    /// @param _tokenId The user's Nft tokenId.
    function getEarned(address _infraredVault, address _rewardToken, uint256 _tokenId) public view returns (uint256) {
        PositionInfo storage position = s_positions[_infraredVault][_tokenId];

        (uint256 balance, uint256 unclaimedReward, uint256 rewardsPerTokenPaid) = (
            position.balance,
            position.tokenRewardInfo[_rewardToken].unclaimedReward,
            position.tokenRewardInfo[_rewardToken].rewardsPerTokenPaid
        );
        uint256 rewardPerTokenDelta;
        rewardPerTokenDelta = getRewardPerToken(_infraredVault, _rewardToken) - rewardsPerTokenPaid;

        return unclaimedReward + (balance * rewardPerTokenDelta) / 1e18;
    }

    /// @notice Gets the value of reward per token of a reward vault.
    /// @param _infraredVault The reward vault address.
    /// @param _rewardToken The reward token address.
    function getRewardPerToken(address _infraredVault, address _rewardToken) public view returns (uint256) {
        return IInfraredVault(_infraredVault).rewardPerToken(_rewardToken);
    }

    /// @notice Gets a user's Nft tokenId's balance accross all strategies.
    /// @param _tokenId The user's nft tokenId.
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[] memory) {
        address[] memory vaults = s_infraredVaults.values();
        UserVaultBalance[] memory userVaultBalance = new UserVaultBalance[](vaults.length);
        uint256 count;

        for (uint256 i; i < vaults.length; ++i) {
            uint256 amount = s_positions[vaults[i]][_tokenId].balance;
            if (amount == 0) {
                continue;
            }
            userVaultBalance[count++] = UserVaultBalance({
                handler: address(this),
                vaultOrStrategy: vaults[i],
                asset: s_vaultStakingToken[vaults[i]],
                balance: amount
            });
        }

        UserVaultBalance[] memory newUserVaultBalance = new UserVaultBalance[](count);

        for (uint256 i; i < newUserVaultBalance.length; ++i) {
            newUserVaultBalance[i] = userVaultBalance[i];
        }

        return newUserVaultBalance;
    }

    /// @notice Gets all the infrared vaults with the given token as the staking token.
    /// @param _token The token contract address.
    /// @return A set of all infrared vaults with the given token as the staking token.
    function getStakingTokenToInfraredVaults(address _token) public view returns (address[] memory) {
        return s_stakingTokenToInfraredVaults[_token].values();
    }

    /// @notice Gets the balance of a user in an infrared vault.
    /// @param _infraredVault The _infraredVault vault address.
    /// @param _tokenId A user's Nft tokenId.
    function getPositionBalance(address _infraredVault, uint256 _tokenId) public view returns (uint256) {
        return s_positions[_infraredVault][_tokenId].balance;
    }
}
