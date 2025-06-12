//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";

import {PositionsNFT} from "@src/poc/PositionsNFT.sol";
import {HelperConfig, NetworkConfig} from "@script/poc/HelperConfig.s.sol";
import {DeployNFT} from "@script/poc/DeployNFT.s.sol";

contract PositionsNFTTest is Test {
    DeployNFT deployer;
    PositionsNFT nft;
    NetworkConfig config;
    HelperConfig helperConfig;

    address user = makeAddr("user");
    address relayer = makeAddr("relayer");
    uint256 startTime = 1735033098;

    function setUp() public {
        deployer = new DeployNFT();
        (helperConfig, nft) = deployer.run();
        config = helperConfig.getActiveNetworkConfig();

        vm.startPrank(config.admin);
        nft.grantRole(nft.RELAYER_ROLE(), relayer);
        vm.stopPrank();
    }

    function test__PositionsNFT__mint() public {
        vm.prank(relayer);
        nft.mint(user);
        assertEq(nft.totalSupply(), 1);
    }

    function test__PositionsNFT__ShouldApplyCoolDown() public {
        vm.warp(startTime);
        vm.prank(relayer);
        nft.mint(user);

        vm.prank(user);
        nft.transferFrom(user, relayer, 1);
        assertEq(nft.lastTransferTimestamp(1), block.timestamp);
    }

    function test__PositionsNFT__ShouldRevertIfCoolDownNotElapsed() public {
        vm.warp(startTime);
        vm.prank(relayer);
        nft.mint(user);

        vm.prank(user);
        nft.transferFrom(user, relayer, 1);

        vm.expectRevert(PositionsNFT.CooldownNotElapsed.selector);
        nft.transferFrom(relayer, user, 1);
    }

    function test__PositionsNFT__ShouldSuccessfullyTransferAfterCoolDown() public {
        vm.warp(startTime);
        vm.prank(relayer);
        nft.mint(user);

        vm.prank(user);
        nft.transferFrom(user, relayer, 1);

        assertEq(nft.ownerOf(1), relayer);

        vm.warp(startTime + nft.COOL_DOWN());
        vm.prank(relayer);
        nft.transferFrom(relayer, user, 1);

        assertEq(nft.ownerOf(1), user);
    }
}
