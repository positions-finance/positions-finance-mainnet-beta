// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Test, console} from "forge-std/Test.sol";

import {IPositionsPOLHandler} from "@src/interfaces/handlers/pol/IPositionsPOLHandler.sol";

import {MockRelayer} from "@test/mock/MockRelayer.sol";
import {PositionsUniV3Handler} from "@src/handlers/uniV3/PositionsUniV3Handler.sol";
import {UniV3HelperConfig} from "@script/handlers/uniV3/UniV3HelperConfig.sol";
import {DeployPositionsUniV3Handler} from "@script/handlers/uniV3/DeployPositionsUniV3Handler.s.sol";

contract PositionsUniV3HandlerTest is Test {
    address public admin;
    address public user;
    address public operator;

    address public nonFungiblePositionManager;

    MockRelayer public relayer;
    PositionsUniV3Handler public uniV3Handler;

    uint256 public uniV3NftTokenId;
    uint256 public tokenId;
    bytes32[] public proof;

    function setUp() external {
        nonFungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
        user = 0xCe70742B6581D33b6bb37CF4CA9902D2bd7A4bC9;
        operator = makeAddr("operator");

        relayer = new MockRelayer();

        UniV3HelperConfig.NetworkConfig memory config = (new UniV3HelperConfig()).getActiveNetworkConfig();
        admin = config.admin;

        DeployPositionsUniV3Handler deployUniV3Handler = new DeployPositionsUniV3Handler();
        uniV3Handler = deployUniV3Handler.run();

        vm.startPrank(admin);
        uniV3Handler.setPositionsRelayer(address(relayer));
        uniV3Handler.setNonFungiblePositionManager(nonFungiblePositionManager);

        uniV3Handler.grantRole(uniV3Handler.RELAYER_ROLE(), admin);
        vm.stopPrank();

        uniV3NftTokenId = 200;
        tokenId = 1;
    }

    function test_setNewRelayer() external {
        address newRelayer = makeAddr("new relayer");

        vm.prank(admin);
        uniV3Handler.setPositionsRelayer(newRelayer);

        assertEq(uniV3Handler.relayer(), newRelayer);
    }

    function test_deposit() external {
        _deposit();

        assertEq(IERC721(nonFungiblePositionManager).ownerOf(uniV3NftTokenId), address(uniV3Handler));
        assertEq(uniV3Handler.getUserNfts(tokenId)[0], uniV3NftTokenId);
    }

    function test_queueWithdraw() external {
        _deposit();
        bytes32 requestId = _queueWithdraw();

        (
            PositionsUniV3Handler.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = uniV3Handler.withdrawData(requestId);

        assertTrue(status == PositionsUniV3Handler.Status.PENDING);
        assertEq(uint256(uint160(poolOrVault)), uniV3NftTokenId);
        assertEq(to, user);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, 1);
        assertEq(handler, address(uniV3Handler));
    }

    function test_acceptWithdrawalRequest() external {
        _deposit();
        bytes32 requestId = _queueWithdraw();

        _approveWithdrawalRequest(requestId);

        (PositionsUniV3Handler.Status status,,,,,) = uniV3Handler.withdrawData(requestId);

        assertEq(uniV3Handler.getUserNfts(tokenId).length, 0);
        assertTrue(status == PositionsUniV3Handler.Status.ACCEPTED);
    }

    function test_completeWithdrawal() external {
        _deposit();
        bytes32 requestId = _queueWithdraw();
        _approveWithdrawalRequest(requestId);

        vm.prank(user);
        uniV3Handler.completeWithdraw(address(uniV3Handler), requestId, proof, "");

        (PositionsUniV3Handler.Status status,,,,,) = uniV3Handler.withdrawData(requestId);

        assertTrue(status == PositionsUniV3Handler.Status.COMPLETED);
        assertEq(IERC721(nonFungiblePositionManager).ownerOf(uniV3NftTokenId), user);
    }

    function test_liquidate() external {
        _deposit();
        _liquidate();

        (
            PositionsUniV3Handler.Status status,
            uint256 poolOrVault,
            address to,
            uint256 nftTokenId,
            uint256 amount,
            address handler
        ) = uniV3Handler.liquidationData(address(uniV3Handler), tokenId);

        assertTrue(status == PositionsUniV3Handler.Status.ACCEPTED);
        assertEq(uint256(uint160(poolOrVault)), uniV3NftTokenId);
        assertEq(to, admin);
        assertEq(nftTokenId, tokenId);
        assertEq(amount, 1);
        assertEq(handler, address(uniV3Handler));
        assertEq(uniV3Handler.getUserNfts(tokenId).length, 0);
    }

    function test_completeLiquidation() external {
        _deposit();
        _liquidate();

        vm.prank(user);
        uniV3Handler.completeLiquidation(address(uniV3Handler), tokenId, "");

        assertEq(IERC721(nonFungiblePositionManager).ownerOf(uniV3NftTokenId), admin);
    }

    function _deposit() internal {
        vm.startPrank(user);
        IERC721(nonFungiblePositionManager).approve(address(uniV3Handler), uniV3NftTokenId);
        uniV3Handler.deposit(address(uniV3Handler), address(uint160(uniV3NftTokenId)), 1, tokenId, proof, "");
        vm.stopPrank();
    }

    function _queueWithdraw() internal returns (bytes32) {
        vm.prank(user);
        return
            uniV3Handler.queueWithdraw(address(uniV3Handler), address(uint160(uniV3NftTokenId)), 1, tokenId, proof, "");
    }

    function _approveWithdrawalRequest(bytes32 _requestId) internal {
        bytes32[] memory requestIds = new bytes32[](1);
        requestIds[0] = _requestId;
        PositionsUniV3Handler.Status[] memory statuses = new PositionsUniV3Handler.Status[](1);
        statuses[0] = PositionsUniV3Handler.Status.ACCEPTED;

        vm.prank(admin);
        uniV3Handler.setWithdrawalStatus(requestIds, statuses);
    }

    function _liquidate() internal {
        vm.prank(admin);
        uniV3Handler.liquidate(address(uniV3Handler), address(uint160(uniV3NftTokenId)), 1, tokenId, admin, "");
    }
}
