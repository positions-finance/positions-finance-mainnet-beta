//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";

import {IBerachainRewardsVault} from "../../interfaces/handlers/pol/IBerachainRewardsVault.sol";
import {IBGT} from "../../interfaces/handlers/pol/IBGT.sol";

/**
 * @title PositionsBGTHandler
 * @notice
 */
abstract contract PositionsBGTHandler is Initializable {
    error PositionsBGTHandler__RedeemBGTForBeraFailed(address receiver, uint256 tokenId, uint256 redeemAmount);

    /// @notice - BGT token contract address
    IBGT public bgt;

    /**
     * @dev - Receive BERA on redeeming BGT
     */
    receive() external payable {}

    /// @dev Disable the iniliaizers of abstract contract
    constructor() {
        _disableInitializers();
    }

    /**
     * Intialize the contract with the BGT token address
     * @param _bgt - BGT token contract address
     */
    function __PositionsBGTHandler_init(address _bgt) internal onlyInitializing {
        bgt = IBGT(_bgt);
    }

    /**
     * @dev - Redeem all BGT of contract for Bera
     */
    function _redeemBGTForBera() internal {
        bgt.redeem(address(this), bgt.balanceOf(address(this)));
    }

    /**
     * @dev - Claim rewards from the reward vaults
     * @param _rewardVaults - Array of reward vaults to claim rewards from
     */
    function claimReward(address[] calldata _rewardVaults) external {
        for (uint256 i; i < _rewardVaults.length; i++) {
            IBerachainRewardsVault(_rewardVaults[i]).getReward(address(this));
        }
    }

    function _checkAndUpdateUnclaimedBGTBalance(address receiver, uint256 _amount) internal virtual;
}
