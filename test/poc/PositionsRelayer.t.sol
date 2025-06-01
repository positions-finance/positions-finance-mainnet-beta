//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {DeployRelayer} from "@script/poc/DeployRelayer.s.sol";
import {PositionsRelayer} from "@src/poc/PositionsRelayer.sol";
import {IPositionsRelayer} from "@src/interfaces/poc/IPositionsRelayer.sol";
import {PositionsClient} from "@test/mock/PositionsClient.m.sol";
import {HelperConfig, HelperConfigClient, NetworkConfig, NetworkConfigClient} from "@script/poc/HelperConfig.s.sol";
import {DeployMockClient} from "@script/poc/DeployMockClient.s.sol";
import {ERC20Mock} from "@test/mock/ERC20Mock.sol";
import {UID} from "@src/lib/UID.sol";

contract PositionsRelayerTest is Test {
    DeployRelayer deployer;
    DeployMockClient clientDeployer;

    PositionsRelayer positionsRelayer;
    PositionsClient client;

    HelperConfig helperConfig;
    HelperConfigClient helperConfigClient;

    ERC20Mock token;
    address relayer = makeAddr("relayer");
    address user = makeAddr("user");

    function setUp() public {
        deployer = new DeployRelayer();
        (helperConfig, positionsRelayer) = deployer.run();

        clientDeployer = new DeployMockClient();
        (helperConfigClient, client) = clientDeployer.run();

        token = new ERC20Mock("Mock", "MOCK");
        token.mint(address(client), 1000e18);

        NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        vm.startPrank(config.admin);
        positionsRelayer.grantRole(positionsRelayer.RELAYER_ROLE(), relayer);
        client.setRelayer(address(positionsRelayer));
        vm.stopPrank();
    }

    function test__PositionsRelayer__updateNFTOwnershipRoot() public {
        bytes32 nftRoot = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        vm.prank(relayer);
        positionsRelayer.updateNFTOwnershipRoot(nftRoot);
        assertEq(positionsRelayer.nftOwnershipRoot(), nftRoot);
    }

    function test__PositionsRelayer__ClientShouldRequestCollateral() public {
        IPositionsRelayer.PositionsCollateralRequest memory request = IPositionsRelayer.PositionsCollateralRequest({
            tokenId: 1,
            protocol: address(client),
            token: address(token),
            owner: user,
            tokenAmount: 1000e18,
            deadline: block.timestamp + 100000,
            data: ""
        });

        //This should be the signature signed by the user that has to be implemented in the client UI
        bytes memory signature = abi.encodePacked("signature");

        vm.prank(user);
        bytes32 requestId = client.requestCollateral(request, signature);

        IPositionsRelayer.RequestStatus status = positionsRelayer.requestStatus(requestId);
        uint256 nonce = positionsRelayer.requestNonce(request.tokenId, block.chainid, request.protocol);

        //Should set the correct status
        assertEq(uint256(status), uint256(IPositionsRelayer.RequestStatus.PENDING));

        //Should increse the user nonce
        assertEq(nonce, 1);
    }

    function test__PositionsRelayer__ShouldEmitEventOnRequestCollateral() public {
        IPositionsRelayer.PositionsCollateralRequest memory request = IPositionsRelayer.PositionsCollateralRequest({
            tokenId: 1,
            protocol: address(client),
            token: address(token),
            owner: user,
            tokenAmount: 1000e18,
            deadline: block.timestamp + 100000,
            data: ""
        });

        //This should be the signature signed by the user that has to be implemented in the client UI
        bytes memory signature = abi.encodePacked("signature");
        bytes32 requestId = UID.generate(1, block.chainid, request.tokenId, request.protocol);

        vm.prank(user);

        vm.expectEmit(true, true, true, false);
        emit IPositionsRelayer.CollateralRequest(requestId, request, signature);
        requestId = client.requestCollateral(request, signature);
    }

    function test__PositionsRelayer__ShouldProcessRequest() public {
        (bytes32 requestId, IPositionsRelayer.PositionsCollateralRequest memory request) = _sendRequest();

        uint256 feeReceipientBalanceBeforeProcess = token.balanceOf(positionsRelayer.feeReceipient());

        vm.prank(relayer);
        (IPositionsRelayer.RequestStatus status,) = positionsRelayer.processRequest(requestId, true);

        //Owner of the NFT should receive the token excluding fee
        uint256 fee = request.tokenAmount * positionsRelayer.feePercentage() / 100_00;
        assertEq(token.balanceOf(user), request.tokenAmount - fee);

        //Fee Receipient should receive the fee
        assertEq(token.balanceOf(positionsRelayer.feeReceipient()), feeReceipientBalanceBeforeProcess + fee);

        //Should set the status to FULLFILED
        assertEq(uint256(status), uint256(IPositionsRelayer.RequestStatus.FULLFILED));
    }

    function _sendRequest()
        internal
        returns (bytes32 requestId, IPositionsRelayer.PositionsCollateralRequest memory request)
    {
        request = IPositionsRelayer.PositionsCollateralRequest({
            tokenId: 1,
            protocol: address(client),
            token: address(token),
            owner: user,
            tokenAmount: 1000e18,
            deadline: block.timestamp + 100000,
            data: ""
        });

        //This should be the signature signed by the user that has to be implemented in the client UI
        bytes memory signature = abi.encodePacked("signature");

        vm.prank(user);
        requestId = client.requestCollateral(request, signature);
    }
}
