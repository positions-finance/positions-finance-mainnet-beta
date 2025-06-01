// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IPositionsPOLHandler} from "@src/interfaces/handlers/pol/IPositionsPOLHandler.sol";
import {IPositionsVaultsEntrypoint} from "@src/interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";

import {MockRelayer} from "@test/mock/MockRelayer.sol";
import {PositionsPOLHandler} from "@src/handlers/pol/PositionsPOLHandler.sol";
import {PositionsVaultsEntrypoint} from "@src/entryPoint/PositionsVaultsEntrypoint.sol";
import {VaultsEntrypointHelperConfig} from "@script/vaultsEntrypoint/VaultsEntrypointHelperConfig.sol";
import {DeployPositionsVaultsEntrypoint} from "@script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol";
import {POLHelperConfig} from "@script/handlers/pol/POLHelperConfig.sol";
import {DeployPOLHandler} from "@script/handlers/pol/DeployPOLHandler.s.sol";

contract PositionsPOLHandlerTest is Test {
    address public admin;
    address public user;
    address public operator;

    address public bgt;

    MockRelayer public relayer;
    PositionsVaultsEntrypoint public entrypoint;
    PositionsPOLHandler public polHandler;

    address public rewardVault;
    IPositionsPOLHandler.RewardVaultInfo public rewardVaultInfo;

    uint256 public tokenId;
    bytes32[] public proof;

    function setUp() external {
        user = makeAddr("user");
        operator = makeAddr("operator");

        relayer = new MockRelayer();

        POLHelperConfig.NetworkConfig memory config = (new POLHelperConfig()).getActiveNetworkConfig();
        admin = config.admin;
        bgt = config.bgt;
        rewardVault = 0x601BB027f525d1aA50cdeD1269910FBC13aaa755;
        rewardVaultInfo = IPositionsPOLHandler.RewardVaultInfo({
            stakingToken: 0x9B01F3C7355188c6c5C56B9e68631A6546A1539f,
            rewardToken: bgt
        });

        DeployPositionsVaultsEntrypoint deployVaultsEntrypoint = new DeployPositionsVaultsEntrypoint();
        entrypoint = deployVaultsEntrypoint.run();

        DeployPOLHandler deployPolHandler = new DeployPOLHandler();
        polHandler = deployPolHandler.run();

        vm.startPrank(admin);
        entrypoint.setPositionsRelayer(address(relayer));

        polHandler.setEntrypoint(address(entrypoint));
        polHandler.setPositionsRelayer(address(relayer));

        entrypoint.addHandler(address(polHandler));
        entrypoint.grantRole(entrypoint.RELAYER_ROLE(), admin);

        address[] memory rewardVaults = new address[](1);
        rewardVaults[0] = rewardVault;
        IPositionsPOLHandler.RewardVaultInfo[] memory rewardVaultsInfo = new IPositionsPOLHandler.RewardVaultInfo[](1);
        rewardVaultsInfo[0] = rewardVaultInfo;
        polHandler.addRewardVaults(rewardVaults, rewardVaultsInfo);
        vm.stopPrank();

        tokenId = 1;
    }

    function test_setNewRelayer() external {
        address newRelayer = makeAddr("new relayer");

        vm.prank(admin);
        entrypoint.setPositionsRelayer(newRelayer);

        assertEq(entrypoint.relayer(), newRelayer);
    }

    function test_addHandler() external {
        address newHandler = makeAddr("new handler");

        vm.prank(admin);
        entrypoint.addHandler(newHandler);

        address[] memory supportedHandlers = entrypoint.getSupportedHandlers();

        assertEq(supportedHandlers.length, 2);
        assertEq(supportedHandlers[1], newHandler);
    }

    function test_removeHandler() external {
        vm.prank(admin);
        entrypoint.removeHandler(address(polHandler));

        address[] memory supportedHandlers = entrypoint.getSupportedHandlers();

        assertEq(supportedHandlers.length, 0);
    }

    function test_deposit() external {
        uint256 depositAmount = 1 * 10 ** (IERC20Metadata(rewardVaultInfo.stakingToken).decimals() - 10);

        _deposit(depositAmount);

        assertEq(polHandler.balanceOf(rewardVault, tokenId), depositAmount);
    }

    function test_queueWithdraw() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(rewardVaultInfo.stakingToken).decimals();

        _deposit(depositAmount);
        bytes32 requestId = _queueWithdraw(depositAmount);

        (
            IPositionsVaultsEntrypoint.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = entrypoint.withdrawData(requestId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.PENDING);
        assertEq(address(uint160(poolOrVault)), rewardVault);
        assertEq(to, user);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, depositAmount);
        assertEq(handler, address(polHandler));
    }

    function test_acceptWithdrawalRequest() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(rewardVaultInfo.stakingToken).decimals();

        _deposit(depositAmount);
        bytes32 requestId = _queueWithdraw(depositAmount);

        _approveWithdrawalRequest(requestId);

        (IPositionsVaultsEntrypoint.Status status,,,,,) = entrypoint.withdrawData(requestId);

        assertEq(polHandler.balanceOf(rewardVault, tokenId), 0);
        assertTrue(status == IPositionsVaultsEntrypoint.Status.ACCEPTED);
    }

    function test_completeWithdrawal() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(rewardVaultInfo.stakingToken).decimals();

        _deposit(depositAmount);
        bytes32 requestId = _queueWithdraw(depositAmount);
        _approveWithdrawalRequest(requestId);

        vm.prank(user);
        entrypoint.completeWithdraw(address(polHandler), requestId, proof, abi.encode(rewardVault));

        (IPositionsVaultsEntrypoint.Status status,,,,,) = entrypoint.withdrawData(requestId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.COMPLETED);
        assertEq(IERC20(rewardVaultInfo.stakingToken).balanceOf(user), depositAmount);
    }

    function test_liquidate() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(rewardVaultInfo.stakingToken).decimals();

        _deposit(depositAmount);
        _liquidate(depositAmount);

        (
            IPositionsVaultsEntrypoint.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = entrypoint.liquidationData(address(polHandler), tokenId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.ACCEPTED);
        assertEq(address(uint160(poolOrVault)), rewardVault);
        assertEq(to, admin);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, depositAmount);
        assertEq(handler, address(polHandler));
        assertEq(polHandler.balanceOf(rewardVault, tokenId), 0);
    }

    function test_completeLiquidation() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(rewardVaultInfo.stakingToken).decimals();

        _deposit(depositAmount);
        _liquidate(depositAmount);

        vm.prank(user);
        entrypoint.completeLiquidation(address(polHandler), tokenId, abi.encode(rewardVault));

        assertEq(IERC20(rewardVaultInfo.stakingToken).balanceOf(admin), depositAmount);
    }

    function _deposit(uint256 _amount) internal {
        deal(rewardVaultInfo.stakingToken, user, _amount);

        vm.startPrank(user);
        IERC20(rewardVaultInfo.stakingToken).approve(address(entrypoint), _amount);
        entrypoint.deposit(
            address(polHandler), rewardVaultInfo.stakingToken, _amount, tokenId, proof, abi.encode(rewardVault)
        );
        vm.stopPrank();
    }

    function _queueWithdraw(uint256 _amount) internal returns (bytes32) {
        vm.prank(user);
        return entrypoint.queueWithdraw(
            address(polHandler), rewardVaultInfo.stakingToken, _amount, tokenId, proof, abi.encode(rewardVault)
        );
    }

    function _approveWithdrawalRequest(bytes32 _requestId) internal {
        bytes32[] memory requestIds = new bytes32[](1);
        requestIds[0] = _requestId;
        IPositionsVaultsEntrypoint.Status[] memory statuses = new IPositionsVaultsEntrypoint.Status[](1);
        statuses[0] = IPositionsVaultsEntrypoint.Status.ACCEPTED;

        vm.prank(admin);
        entrypoint.setWithdrawalStatus(requestIds, statuses);
    }

    function _liquidate(uint256 _amount) internal {
        vm.prank(admin);
        entrypoint.liquidate(
            address(polHandler), rewardVaultInfo.stakingToken, _amount, tokenId, admin, abi.encode(rewardVault)
        );
    }
}
