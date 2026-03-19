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
        address proxyAddress = 0x0Ea8C132F7D30E01E1F99988cEE8E195A89D29F7;

        // Replace with the address of the implementation contract you already deployed
        address existingImplementation = 0xf767F93dd72e909b17aeD00b19dA76a8E9764964;

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