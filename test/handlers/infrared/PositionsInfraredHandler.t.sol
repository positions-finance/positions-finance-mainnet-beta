// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "forge-std-1.9.7/src/Test.sol";

import {IHandler} from "@src/interfaces/handlers/IHandler.sol";
import {IInfraredVault} from "@src/interfaces/handlers/infrared/IInfraredVault.sol";
import {IPositionsVaultsEntrypoint} from "@src/interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";

import {MockRelayer} from "@test/mock/MockRelayer.sol";
import {PositionsInfraredVaultHandler} from "@src/handlers/infrared/PositionsInfraredVaultHandler.sol";
import {InfraredVaultHandlerHelperConfig} from "@script/handlers/infrared/InfraredVaultHandlerHelperConfig.sol";
import {DeployPositionsInfraredVaultHandler} from "@script/handlers/infrared/DeployPositionsInfraredVaultHandler.s.sol";
import {PositionsVaultsEntrypoint} from "@src/entryPoint/PositionsVaultsEntrypoint.sol";
import {VaultsEntrypointHelperConfig} from "@script/vaultsEntrypoint/VaultsEntrypointHelperConfig.sol";
import {DeployPositionsVaultsEntrypoint} from "@script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol";

contract PositionsInfraredVaultHandlerTest is Test {
    address public infraredByusdHoneyRewardVault = 0xbbB228B0D7D83F86e23a5eF3B1007D0100581613;
    address public byusdHoney = 0xdE04c469Ad658163e2a5E860a03A86B52f6FA8C8;
    address public wberaHoneyVault = 0x418D63947889e55C16280Cb7785cF84EF081F224;
    address public wberaHoney = 0x4a254B11810B8EBb63C5468E438FC561Cb1bB1da;

    address public user;
    address public admin;
    MockRelayer public relayer;
    PositionsVaultsEntrypoint public entrypoint;
    PositionsInfraredVaultHandler public infraredVaultHandler;

    uint256 public tokenId;
    bytes32[] public proof;

    function setUp() public {
        user = makeAddr("user");

        relayer = new MockRelayer();

        DeployPositionsVaultsEntrypoint deployVaultsEntrypoint = new DeployPositionsVaultsEntrypoint();
        entrypoint = deployVaultsEntrypoint.run();

        InfraredVaultHandlerHelperConfig infraredVaultHandlerHelperConfig;
        (infraredVaultHandlerHelperConfig, infraredVaultHandler) = (new DeployPositionsInfraredVaultHandler()).run();
        admin = infraredVaultHandlerHelperConfig.getActiveNetworkConfig().admin;

        vm.startPrank(admin);
        entrypoint.setPositionsRelayer(address(relayer));
        entrypoint.addHandler(address(infraredVaultHandler));
        entrypoint.grantRole(entrypoint.RELAYER_ROLE(), admin);

        infraredVaultHandler.setEntrypoint(address(entrypoint));
        infraredVaultHandler.setRelayer(address(relayer));

        address[] memory vaults = new address[](1);
        vaults[0] = infraredByusdHoneyRewardVault;
        address[] memory stakingTokens = new address[](1);
        stakingTokens[0] = byusdHoney;
        infraredVaultHandler.addInfraredVaults(vaults, stakingTokens);
        vm.stopPrank();

        tokenId = 1;
    }

    function test_checkInitialization() external view {
        address[] memory handlers = entrypoint.getSupportedHandlers();
        uint256 length = handlers.length;
        bool supported;

        for (uint256 i; i < length; ++i) {
            if (handlers[i] == address(infraredVaultHandler)) supported = true;
        }

        assertTrue(supported);
        assertEq(infraredVaultHandler.getInfraredVaults().length, 1);
        assertEq(infraredVaultHandler.getInfraredVaults()[0], infraredByusdHoneyRewardVault);
        assertEq(infraredVaultHandler.getInfraredVaultStakingToken(infraredByusdHoneyRewardVault), byusdHoney);
        assertEq(infraredVaultHandler.getStakingTokenToInfraredVaults(byusdHoney).length, 1);
        assertEq(infraredVaultHandler.getStakingTokenToInfraredVaults(byusdHoney)[0], infraredByusdHoneyRewardVault);
    }

    function test_canAddAndRemoveOtherInfraredRewardVault() external {
        address[] memory vaults = new address[](1);
        vaults[0] = wberaHoneyVault;
        address[] memory stakingTokens = new address[](1);
        stakingTokens[0] = wberaHoney;

        vm.prank(admin);
        infraredVaultHandler.addInfraredVaults(vaults, stakingTokens);

        assertEq(infraredVaultHandler.getInfraredVaults().length, 2);
        assertEq(infraredVaultHandler.getInfraredVaults()[1], wberaHoneyVault);
        assertEq(infraredVaultHandler.getInfraredVaultStakingToken(wberaHoneyVault), wberaHoney);
        assertEq(infraredVaultHandler.getStakingTokenToInfraredVaults(wberaHoney).length, 1);
        assertEq(infraredVaultHandler.getStakingTokenToInfraredVaults(wberaHoney)[0], wberaHoneyVault);

        vm.prank(admin);
        infraredVaultHandler.removeInfraredVaults(vaults);

        assertEq(infraredVaultHandler.getInfraredVaults().length, 1);
        assertEq(infraredVaultHandler.getInfraredVaults()[0], infraredByusdHoneyRewardVault);
        assertEq(infraredVaultHandler.getStakingTokenToInfraredVaults(wberaHoney).length, 0);
    }

    function test_depositIntoInfraredVaultOnce() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();

        deal(byusdHoney, user, depositAmount);

        uint256 userByusdHoneyBalanceBefore = IERC20(byusdHoney).balanceOf(user);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        uint256 userByusdHoneyBalanceAfter = IERC20(byusdHoney).balanceOf(user);

        assertEq(userByusdHoneyBalanceBefore - userByusdHoneyBalanceAfter, depositAmount);
        assertEq(infraredVaultHandler.getPositionBalance(infraredByusdHoneyRewardVault, tokenId), depositAmount);

        address[] memory rewardTokens = IInfraredVault(infraredByusdHoneyRewardVault).getAllRewardTokens();
        for (uint256 i; i < rewardTokens.length; ++i) {
            assertEq(infraredVaultHandler.getEarned(infraredByusdHoneyRewardVault, rewardTokens[i], tokenId), 0);
        }
    }

    function test_depositIntoInfraredVaultMultipleTimes() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount * 2);
        uint256 userByusdHoneyBalanceBefore = IERC20(byusdHoney).balanceOf(user);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount * 2);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        uint256 userByusdHoneyBalanceAfter = IERC20(byusdHoney).balanceOf(user);

        assertEq(userByusdHoneyBalanceBefore - userByusdHoneyBalanceAfter, depositAmount * 2);
        assertEq(infraredVaultHandler.getPositionBalance(infraredByusdHoneyRewardVault, tokenId), depositAmount * 2);

        address[] memory rewardTokens = IInfraredVault(infraredByusdHoneyRewardVault).getAllRewardTokens();
        for (uint256 i; i < rewardTokens.length; ++i) {
            assertEq(infraredVaultHandler.getEarned(infraredByusdHoneyRewardVault, rewardTokens[i], tokenId), 0);
        }
    }

    function test_queueWithdrawFromInfraredVault() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        bytes32 requestId = entrypoint.queueWithdraw(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        (
            IPositionsVaultsEntrypoint.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = entrypoint.withdrawData(requestId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.PENDING);
        assertEq(address(uint160(poolOrVault)), infraredByusdHoneyRewardVault);
        assertEq(to, user);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, depositAmount);
        assertEq(handler, address(infraredVaultHandler));
    }

    function test_acceptWithdrawalRequest() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        bytes32 requestId = entrypoint.queueWithdraw(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        _approveWithdrawalRequest(requestId);

        (IPositionsVaultsEntrypoint.Status status,,,,,) = entrypoint.withdrawData(requestId);

        assertEq(infraredVaultHandler.getPositionBalance(infraredByusdHoneyRewardVault, tokenId), 0);
        assertTrue(status == IPositionsVaultsEntrypoint.Status.ACCEPTED);
    }

    function test_completeWithdrawal() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        bytes32 requestId = entrypoint.queueWithdraw(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        _approveWithdrawalRequest(requestId);

        vm.startPrank(user);
        entrypoint.completeWithdraw(
            address(infraredVaultHandler), requestId, proof, abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        (IPositionsVaultsEntrypoint.Status status,,,,,) = entrypoint.withdrawData(requestId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.COMPLETED);
        assertEq(IERC20(byusdHoney).balanceOf(user), depositAmount);
    }

    function test_liquidate() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        vm.prank(admin);
        entrypoint.liquidate(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            admin,
            abi.encode(infraredByusdHoneyRewardVault)
        );

        (
            IPositionsVaultsEntrypoint.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = entrypoint.liquidationData(address(infraredVaultHandler), tokenId);

        assertTrue(status == IPositionsVaultsEntrypoint.Status.ACCEPTED);
        assertEq(address(uint160(poolOrVault)), infraredByusdHoneyRewardVault);
        assertEq(to, admin);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, depositAmount);
        assertEq(handler, address(infraredVaultHandler));
        assertEq(infraredVaultHandler.getPositionBalance(infraredByusdHoneyRewardVault, tokenId), 0);
    }

    function test_completeLiquidation() external {
        uint256 depositAmount = 1 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        vm.startPrank(admin);
        entrypoint.liquidate(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            admin,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        entrypoint.completeLiquidation(
            address(infraredVaultHandler), tokenId, abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        assertEq(IERC20(byusdHoney).balanceOf(admin), depositAmount);
    }

    function test_claimRewardsFromInfraredVault() external {
        uint256 depositAmount = 100 * 10 ** IERC20Metadata(byusdHoney).decimals();
        deal(byusdHoney, user, depositAmount);

        vm.startPrank(user);
        IERC20(byusdHoney).approve(address(entrypoint), depositAmount);
        entrypoint.deposit(
            address(infraredVaultHandler),
            byusdHoney,
            depositAmount,
            tokenId,
            proof,
            abi.encode(infraredByusdHoneyRewardVault)
        );
        vm.stopPrank();

        uint256 skipBy = 20 days;
        skip(skipBy);

        address rewardToken = IInfraredVault(infraredByusdHoneyRewardVault).getAllRewardTokens()[0];
        uint256 earned = infraredVaultHandler.getEarned(infraredByusdHoneyRewardVault, rewardToken, tokenId);
        address[] memory infraredVaults = new address[](1);
        infraredVaults[0] = infraredByusdHoneyRewardVault;

        uint256 userRewardTokenBalanceBefore = IERC20(rewardToken).balanceOf(user);

        vm.prank(user);
        infraredVaultHandler.getReward(infraredVaults, tokenId, proof, user);

        uint256 user1RewardTokenBalanceAfter = IERC20(rewardToken).balanceOf(user);
        uint256 handlerRewardTokenBalance = IERC20(rewardToken).balanceOf(address(infraredVaultHandler));

        assertEq(user1RewardTokenBalanceAfter - userRewardTokenBalanceBefore, earned);
        assertEq(handlerRewardTokenBalance, 0);
    }

    function _approveWithdrawalRequest(bytes32 _requestId) internal {
        bytes32[] memory requestIds = new bytes32[](1);
        requestIds[0] = _requestId;
        IPositionsVaultsEntrypoint.Status[] memory statuses = new IPositionsVaultsEntrypoint.Status[](1);
        statuses[0] = IPositionsVaultsEntrypoint.Status.ACCEPTED;

        vm.prank(admin);
        entrypoint.setWithdrawalStatus(requestIds, statuses);
    }
}
