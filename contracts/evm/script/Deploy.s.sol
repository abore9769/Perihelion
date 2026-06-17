// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { PerihelionEscrow } from "../src/PerihelionEscrow.sol";

/// @notice Deploys the Perihelion escrow.
/// @dev Set PERIHELION_ENDPOINT to the LayerZero endpoint address before running:
///      forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
contract Deploy is Script {
    function run() external returns (PerihelionEscrow escrow) {
        address endpoint = vm.envAddress("PERIHELION_ENDPOINT");
        vm.startBroadcast();
        escrow = new PerihelionEscrow(endpoint);
        vm.stopBroadcast();
    }
}
