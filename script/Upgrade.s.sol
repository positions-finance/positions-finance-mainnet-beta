// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/polymarket/PolymarketVault.sol";

contract UpgradePolymarketVault is Script {
    function run() external {
        // 1. Hardcode your private key as a uint256 hex literal
        // Replace the placeholder below with your actual private key
        uint256 deployerPrivateKey = 0x0;

        // 2. Hardcode the Proxy and Existing Implementation addresses
        address proxyAddress = 0xf79fc543a49C3f28156452587cfd77cbD2aD075b;

        // Replace with the address of the implementation contract you already deployed
        address existingImplementation = 0x367be24bEb6e0d1513DabbF43907449c0e8ca28B;

        vm.startBroadcast(deployerPrivateKey);

        console.log("Target Proxy:", proxyAddress);
        console.log("Targeting Existing Implementation:", existingImplementation);

        // 3. Initialize the Interface on the Proxy Address
        PolymarketVault proxy = PolymarketVault(payable(proxyAddress));

        try proxy.upgradeToAndCall(existingImplementation, "") {
            console.log("Successfully upgraded proxy:", proxyAddress);
        } catch Error(string memory reason) {
            console.log("Upgrade failed:", reason);
        } catch {
            console.log("Upgrade failed with unknown error");
        }

        vm.stopBroadcast();
    }
}