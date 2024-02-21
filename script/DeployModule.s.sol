// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { RegistryDeployer } from "modulekit/deployment/RegistryDeployer.sol";
import { FarcasterNetwork } from "frame-verifier/Encoder.sol";

// Import modules here
import { FrameValidator } from "../src/FrameValidator.sol";

/// @title DeployModuleScript
contract DeployModuleScript is Script, RegistryDeployer {
    function run() public {
        string memory baseUrl = vm.envString("BASE_URL");
        FarcasterNetwork farcasterNetwork = FarcasterNetwork.FARCASTER_NETWORK_MAINNET;

        // Setup module bytecode, deploy params, and data
        bytes memory bytecode = type(FrameValidator).creationCode;
        bytes memory deployParams = abi.encode(baseUrl, farcasterNetwork);
        bytes memory data = "";

        // Get private key for deployment
        vm.startBroadcast(vm.envUint("PK"));

        // Deploy module
        address module = deployModule({
            code: bytecode,
            deployParams: deployParams,
            salt: bytes32(0),
            data: data
        });

        // Stop broadcast and log module address
        vm.stopBroadcast();
        console.log("Module deployed at: %s", module);
    }
}
