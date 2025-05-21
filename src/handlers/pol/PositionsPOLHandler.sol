//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IBerachainRewardsVault} from "../../interfaces/handlers/pol/IBerachainRewardsVault.sol";
import {IPositionsPOLHandler} from "../../interfaces/handlers/pol/IPositionsPOLHandler.sol";
import {IPositionsVaultsEntrypoint} from "../../interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IPositionsRelayer} from "./../../interfaces/poc/IPositionsRelayer.sol";

import {UserVaultBalance} from "../../utils/PositionsDataProvider.sol";
import {PositionsBGTHandler} from "./PositionsBGTHandler.sol";

/// @title PositionsPOLHandler.
/// @author Positions Team.
/// @notice Handler to track and manage deposits and rewards on Bera reward vaults.
contract PositionsPOLHandler is
    IPositionsPOLHandler,
    Initializable,
    PositionsBGTHandler,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    /// @notice The upgrader role can upgrade the proxy to a new implementation.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Pricesion for BGT.
    uint256 internal constant PRECISION = 1e18;

    /// @notice The positions relayer contract address.
    address public relayer;
    /// @notice The positions vaults entrypoint.
    address public entrypoint;
    /// @dev A set of supported reward vaults.
    EnumerableSet.AddressSet private rewardVaults;
    /// @notice Mapping to store reward vault data.
    mapping(address => RewardVaultInfo) public rewardVaultInfo;
    /// @dev Mapping to track user deposits in reward vaults.
    mapping(address underlyingVault => mapping(uint256 tokenId => PositionInfo)) private positionInfoMaps;

    modifier onlyEntryPoint() {
        if (msg.sender != entrypoint) revert PositionsPOLHandler__NotEntryPoint();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _entryPoint The vaults entrypoint address.
    /// @param _admin The admin address.
    /// @param _upgrader The upgrader address which receives the upgrader role.
    /// @param _relayer The positions relayer address.
    /// @param _bgt The BGT token address.
    function initialize(address _entryPoint, address _admin, address _upgrader, address _relayer, address _bgt)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __PositionsBGTHandler_init(_bgt);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);

        relayer = _relayer;
        entrypoint = _entryPoint;
    }

    /// @notice Admin-only function to set the new relayer address.
    /// @param _newRelayer The new positions relayer contract address.
    function setPositionsRelayer(address _newRelayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayer = _newRelayer;

        emit RelayerSet(_newRelayer);
    }

    /// @notice Allows the admin to set the new entrypoint.
    /// @param _newEntrypoint The new entrypoint contract address.
    function setEntrypoint(address _newEntrypoint) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entrypoint = _newEntrypoint;

        emit EntrypointSet(_newEntrypoint);
    }

    /// @notice Admin-only function to support new reward vaults.
    /// @param _rewardVaults The reward vault addresses.
    /// @param _rewardVaultInfos The reward vault data.
    function addRewardVaults(address[] calldata _rewardVaults, RewardVaultInfo[] calldata _rewardVaultInfos)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_rewardVaults.length != _rewardVaultInfos.length) {
            revert PositionsPOLHandler__ArrayLengthMismatch();
        }

        for (uint256 i; i < _rewardVaults.length; ++i) {
            rewardVaultInfo[_rewardVaults[i]] = _rewardVaultInfos[i];
            rewardVaults.add(_rewardVaults[i]);

            emit RewardVaultAdded(_rewardVaults[i], _rewardVaultInfos[i]);
        }
    }

    /// @notice Admin-only function to remove exisiting reward vaults.
    /// @param _rewardVaults The reward vault addresses.
    function removeRewardVaults(address[] calldata _rewardVaults) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i; i < _rewardVaults.length; ++i) {
            rewardVaults.remove(_rewardVaults[i]);
            delete rewardVaultInfo[_rewardVaults[i]];

            emit RewardVaultRemoved(_rewardVaults[i]);
        }
    }

    /// @notice Enables a user to deposit into a reward vault.
    /// @param _token The token address.
    /// @param _amount The amount of token to deposit.
    /// @param _tokenId The user's Nft token Id.
    /// @param _additionalData The additional bytes data to be decoded into reward vault address.
    function deposit(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData)
        external
        onlyEntryPoint
    {
        address rewardVaultAddr = abi.decode(_additionalData, (address));
        _checkIfRewardVaultExists(rewardVaultAddr);

        RewardVaultInfo memory rewardVaultData = rewardVaultInfo[rewardVaultAddr];
        if (_token != rewardVaultData.stakingToken) revert PositionsPOLHandler__NotStakingToken();

        IERC20(rewardVaultData.stakingToken).approve(rewardVaultAddr, _amount);
        _updateReward(rewardVaultAddr, _tokenId);
        IBerachainRewardsVault(rewardVaultAddr).stake(_amount);

        positionInfoMaps[rewardVaultAddr][_tokenId].balance += _amount;
    }

    /// @notice Queues tokens for withdrawal from a reward vault.
    /// @param _token The token address.
    /// @param _amount The amount of token to deposit.
    /// @param _tokenId The user's Nft token Id.
    /// @param _additionalData The additional bytes data to be decoded into reward vault address.
    function queueWithdraw(address _token, uint256 _amount, uint256 _tokenId, bytes calldata _additionalData)
        external
        onlyEntryPoint
    {
        address rewardVaultAddr = abi.decode(_additionalData, (address));
        _checkIfRewardVaultExists(rewardVaultAddr);

        RewardVaultInfo memory rewardVaultData = rewardVaultInfo[rewardVaultAddr];
        if (_token != rewardVaultData.stakingToken) revert PositionsPOLHandler__NotStakingToken();

        uint256 positionBalance = positionInfoMaps[rewardVaultAddr][_tokenId].balance;
        if (positionBalance < _amount) {
            revert PositionsPOLHandler__InsufficientBalance(_tokenId, positionBalance, _amount);
        }

        _updateReward(rewardVaultAddr, _tokenId);
    }

    /// @notice Withdraw tokens from a reward vault.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    /// @param _to The address to direct the withdrawn tokens to.
    /// @return The token address.
    /// @return The amount of tokens withdrawn.
    function completeWithdraw(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        address _to,
        bytes calldata /*_additionalData*/
    ) external onlyEntryPoint returns (address, uint256) {
        address vault = address(uint160(_withdrawData.poolOrVault));

        _checkIfRewardVaultExists(vault);

        RewardVaultInfo memory rewardVaultData = rewardVaultInfo[vault];
        uint256 amount = _withdrawData.amount;

        IBerachainRewardsVault(vault).withdraw(amount);
        IERC20(rewardVaultData.stakingToken).safeTransfer(_to, amount);

        return (rewardVaultData.stakingToken, amount);
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
        address, /*_liquidator*/
        bytes calldata _additionalData
    ) external onlyEntryPoint {
        address rewardVaultAddr = abi.decode(_additionalData, (address));
        _checkIfRewardVaultExists(rewardVaultAddr);
        if (_token != rewardVaultInfo[rewardVaultAddr].stakingToken) revert PositionsPOLHandler__NotStakingToken();

        uint256 positionBalance = positionInfoMaps[rewardVaultAddr][_tokenId].balance;
        if (positionBalance < _amount) {
            revert PositionsPOLHandler__InsufficientBalance(_tokenId, positionBalance, _amount);
        }

        _updateReward(rewardVaultAddr, _tokenId);

        positionInfoMaps[rewardVaultAddr][_tokenId].balance -= _amount;
    }

    /// @notice Complete a liquidation and withdraw funds.
    /// @param _withdrawData The withdrawal data passed by the entrypoint contract.
    /// @param _additionalData The additional bytes data to be decoded into the reward vault address.
    function completeLiquidation(
        IPositionsVaultsEntrypoint.WithdrawData memory _withdrawData,
        bytes calldata _additionalData
    ) external onlyEntryPoint returns (address, uint256) {
        address rewardVaultAddr = abi.decode(_additionalData, (address));
        _checkIfRewardVaultExists(rewardVaultAddr);

        _updateReward(rewardVaultAddr, _withdrawData.tokenId);

        IBerachainRewardsVault(rewardVaultAddr).withdraw(_withdrawData.amount);
        IERC20(rewardVaultInfo[rewardVaultAddr].stakingToken).safeTransfer(_withdrawData.to, _withdrawData.amount);

        return (rewardVaultInfo[rewardVaultAddr].stakingToken, _withdrawData.amount);
    }

    /// @notice Callback into the handler once a withdrawal request is accepted.
    /// @param _withdrawalData The withdrawal data.
    function withdrawalRequestAccepted(IPositionsVaultsEntrypoint.WithdrawData memory _withdrawalData)
        external
        onlyEntryPoint
    {
        positionInfoMaps[address(uint160(_withdrawalData.poolOrVault))][_withdrawalData.tokenId].balance -=
            _withdrawalData.amount;
    }

    /// @notice Redeems BGT rewards for bera native gas token.
    /// @param _rewardVaults The reward vault addresses.
    /// @param _tokenId The user's nft tokenId.
    /// @param _proof The merkle proof to verify Nft tokenId ownership.
    function redeemBGTForBera(address[] calldata _rewardVaults, uint256 _tokenId, bytes32[] calldata _proof) external {
        _validateNFTOwnership(_tokenId, _proof);
        address receiver = msg.sender;

        uint256 totalRedeemAmount;
        for (uint256 i; i < _rewardVaults.length;) {
            address _rewardVault = _rewardVaults[i];

            if (!rewardVaults.contains(_rewardVault)) {
                unchecked {
                    ++i;
                }
                continue;
            }

            IBerachainRewardsVault(_rewardVault).getReward(address(this));

            uint256 earnedAmount = earned(_rewardVault, _tokenId);

            positionInfoMaps[_rewardVault][_tokenId].unclaimedReward = 0;
            positionInfoMaps[_rewardVault][_tokenId].rewardsPerTokenPaid = rewardPerToken(_rewardVault);

            totalRedeemAmount += earnedAmount;

            unchecked {
                ++i;
            }
        }

        if (address(this).balance < totalRedeemAmount) {
            _redeemBGTForBera();
        }

        if (address(this).balance < totalRedeemAmount) {
            revert PositionsBGTHandler__RedeemBGTForBeraFailed(receiver, _tokenId, totalRedeemAmount);
        }

        (bool success,) = receiver.call{value: totalRedeemAmount}("");

        if (!success) {
            revert PositionsBGTHandler__RedeemBGTForBeraFailed(receiver, _tokenId, totalRedeemAmount);
        }

        emit RedeemBGTForBera(receiver, _tokenId, totalRedeemAmount);
    }

    function _updateReward(address _rewardVault, uint256 _tokenId) internal {
        uint256 _rewardPerToken = rewardPerToken(_rewardVault);

        PositionInfo storage info = positionInfoMaps[_rewardVault][_tokenId];
        (info.unclaimedReward, info.rewardsPerTokenPaid) = (earned(_rewardVault, _tokenId), _rewardPerToken);
    }

    function _checkIfRewardVaultExists(address _rewardVault) internal view {
        if (!rewardVaults.contains(_rewardVault)) {
            revert PositionsPOLHandler__RewardVaultDoesNotExist();
        }
    }

    function _validateNFTOwnership(uint256 _tokenId, bytes32[] calldata _proof) internal view {
        if (!IPositionsRelayer(relayer).verifyNFTOwnership(msg.sender, _tokenId, _proof)) {
            revert PositionsPOLHandler__NFTOwnershipVerificationFailed(msg.sender, _tokenId);
        }
    }

    function _checkAndUpdateUnclaimedBGTBalance(address receiver, uint256 _amount) internal override {}

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    /// @notice Gets the total BGT a user earned from a reward vault.
    /// @param _rewardVault The reward vault address.
    /// @param _tokenId The user's Nft tokenId.
    function earned(address _rewardVault, uint256 _tokenId) public view returns (uint256) {
        PositionInfo storage info = positionInfoMaps[_rewardVault][_tokenId];

        (uint256 balance, uint256 unclaimedReward, uint256 rewardsPerTokenPaid) =
            (info.balance, info.unclaimedReward, info.rewardsPerTokenPaid);
        uint256 rewardPerTokenDelta;
        unchecked {
            rewardPerTokenDelta = rewardPerToken(_rewardVault) - rewardsPerTokenPaid;
        }
        return unclaimedReward + balance.mulDiv(rewardPerTokenDelta, PRECISION);
    }

    /// Gets the value of reward per token of a reward vault.
    /// @param _rewardVault The reward vault address.
    function rewardPerToken(address _rewardVault) public view returns (uint256) {
        return IBerachainRewardsVault(_rewardVault).rewardPerToken();
    }

    /// @notice Gets the balance of a user in a reward vault.
    /// @param _rewardVault The reward vault address.
    /// @param _tokenId A user's Nft tokenId.
    function balanceOf(address _rewardVault, uint256 _tokenId) public view returns (uint256) {
        return positionInfoMaps[_rewardVault][_tokenId].balance;
    }

    /// @notice Gets a user's Nft tokenId's balance accross all strategies.
    /// @param _tokenId The user's nft tokenId.
    function getUserVaultsBalance(uint256 _tokenId) external view returns (UserVaultBalance[] memory) {
        address[] memory vaults = rewardVaults.values();
        UserVaultBalance[] memory userVaultBalance = new UserVaultBalance[](vaults.length);
        uint256 count;

        for (uint256 i; i < vaults.length; ++i) {
            uint256 amount = positionInfoMaps[vaults[i]][_tokenId].balance;
            if (amount == 0) {
                continue;
            }
            userVaultBalance[count++] = UserVaultBalance({
                handler: address(this),
                vaultOrStrategy: vaults[i],
                asset: rewardVaultInfo[vaults[i]].stakingToken,
                balance: amount
            });
        }

        UserVaultBalance[] memory newUserVaultBalance = new UserVaultBalance[](count);

        for (uint256 i; i < newUserVaultBalance.length; ++i) {
            newUserVaultBalance[i] = userVaultBalance[i];
        }

        return newUserVaultBalance;
    }
}
