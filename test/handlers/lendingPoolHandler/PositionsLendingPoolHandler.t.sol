// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IPositionsPOLHandler} from "@src/interfaces/handlers/pol/IPositionsPOLHandler.sol";
import {IPositionsVaultsEntrypoint} from "@src/interfaces/entryPoint/IPositionsVaultsEntrypoint.sol";
import {IPositionsLendingPool} from "@src/interfaces/protocols/lendingPool/IPositionsLendingPool.sol";

import {MockRelayer} from "@test/mock/MockRelayer.sol";
import {PositionsLendingPoolHandler} from "@src/handlers/lendingPool/PositionsLendingPoolHandler.sol";
import {PositionsVaultsEntrypoint} from "@src/entryPoint/PositionsVaultsEntrypoint.sol";
import {VaultsEntrypointHelperConfig} from "@script/vaultsEntrypoint/VaultsEntrypointHelperConfig.sol";
import {DeployPositionsVaultsEntrypoint} from "@script/vaultsEntrypoint/DeployPositionsVaultsEntrypoint.s.sol";
import {LendingPoolHelperConfig} from "@script/handlers/lendingPool/LendingPoolHelperConfig.sol";
import {DeployPositionsLendingPoolHandler} from "@script/handlers/lendingPool/DeployPositionsLendingPoolHandler.s.sol";

contract PositionsLendingPoolHandlerTest is Test {
    address public admin;
    address public user;
    address public operator;

    MockRelayer public relayer;
    PositionsVaultsEntrypoint public entrypoint;
    PositionsLendingPoolHandler public lendingPoolHandler;

    address public lendingPool;
    uint256 public tokenId;
    bytes32[] public proof;
    address public constant HONEY = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;

    function setUp() external {
        user = makeAddr("user");
        operator = makeAddr("operator");

        relayer = new MockRelayer();

        LendingPoolHelperConfig.NetworkConfig memory config = (new LendingPoolHelperConfig()).getActiveNetworkConfig();
        admin = config.admin;
        lendingPool = config.lendingPool;

        DeployPositionsVaultsEntrypoint deployVaultsEntrypoint = new DeployPositionsVaultsEntrypoint();
        entrypoint = deployVaultsEntrypoint.run();

        DeployPositionsLendingPoolHandler deployLendingPoolHandler = new DeployPositionsLendingPoolHandler();
        lendingPoolHandler = deployLendingPoolHandler.run();

        vm.startPrank(admin);
        entrypoint.setPositionsRelayer(address(relayer));

        lendingPoolHandler.setEntrypoint(address(entrypoint));

        entrypoint.addHandler(address(lendingPoolHandler));
        entrypoint.grantRole(entrypoint.RELAYER_ROLE(), admin);
        vm.stopPrank();

        tokenId = 1;
    }

    function test_deposit() external {
        uint256 depositAmount = 100e6;
        _deposit(depositAmount);

        (uint256 amount, uint256 supplyIndexSnapshot) = lendingPoolHandler.positions(tokenId, HONEY);
        (,, uint256 supplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(HONEY);

        assertEq(amount, depositAmount);
        assertEq(supplyIndexSnapshot, supplyIndex);
    }

    function test_queueWithdraw() external {
        uint256 depositAmount = 100e6;
        _deposit(depositAmount);

        bytes32 requestId = _queueWithdrawal(depositAmount);

        (
            IPositionsVaultsEntrypoint.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = entrypoint.withdrawData(requestId);

        assertEq(uint8(status), uint8(IPositionsVaultsEntrypoint.Status.PENDING));
        assertEq(address(uint160(poolOrVault)), HONEY);
        assertEq(to, user);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, depositAmount);
        assertEq(handler, address(lendingPoolHandler));
    }

    function test_completeWithdrawal() external {
        uint256 depositAmount = 100e6;
        _deposit(depositAmount);

        bytes32 requestId = _queueWithdrawal(depositAmount);
        _approveWithdrawalRequest(requestId);

        vm.prank(user);
        entrypoint.completeWithdraw(address(lendingPoolHandler), requestId, proof, "");

        (uint256 amount, uint256 supplyIndexSnapshot) = lendingPoolHandler.positions(tokenId, HONEY);
        (,, uint256 supplyIndex,,,) = IPositionsLendingPool(lendingPool).poolData(HONEY);

        assertEq(amount, 0);
        assertEq(supplyIndexSnapshot, supplyIndex);
        assertEq(IERC20(HONEY).balanceOf(user), depositAmount);
    }

    function test_liquidate() external {
        uint256 depositAmount = 100e6;
        _deposit(depositAmount);

        _liquidate(depositAmount);

        (uint256 amount,) = lendingPoolHandler.positions(tokenId, HONEY);

        assertEq(amount, 0);
    }

    function test_completeLiquidation() external {
        uint256 depositAmount = 100e6;
        _deposit(depositAmount);
        _liquidate(depositAmount);

        vm.prank(admin);
        entrypoint.completeLiquidation(address(lendingPoolHandler), tokenId, "");

        assertEq(IERC20(HONEY).balanceOf(admin), depositAmount);
    }

    function _deposit(uint256 _amount) internal {
        deal(HONEY, user, _amount);

        vm.startPrank(user);
        IERC20(HONEY).approve(address(entrypoint), _amount);
        entrypoint.deposit(address(lendingPoolHandler), HONEY, _amount, tokenId, proof, "");
        vm.stopPrank();
    }

    function _queueWithdrawal(uint256 _amount) internal returns (bytes32) {
        vm.prank(user);
        return entrypoint.queueWithdraw(address(lendingPoolHandler), HONEY, _amount, tokenId, proof, abi.encode(HONEY));
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
        entrypoint.liquidate(address(lendingPoolHandler), HONEY, _amount, tokenId, admin, abi.encode(HONEY));
    }
}
