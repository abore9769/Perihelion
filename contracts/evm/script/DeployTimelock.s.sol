// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { PerihelionTimelock } from "../src/PerihelionTimelock.sol";

/// @notice Deploys the M-of-N timelock multisig that will own the escrow.
/// @dev Configure before running:
///        PERIHELION_TL_OWNERS    - comma-separated owner addresses
///        PERIHELION_TL_THRESHOLD - confirmations required (M)
///        PERIHELION_TL_DELAY     - execution delay in seconds
///      forge script script/DeployTimelock.s.sol --rpc-url $RPC --broadcast
contract DeployTimelock is Script {
    function run() external returns (PerihelionTimelock timelock) {
        address[] memory owners = vm.envAddress("PERIHELION_TL_OWNERS", ",");
        uint256 threshold = vm.envUint("PERIHELION_TL_THRESHOLD");
        uint256 delay = vm.envUint("PERIHELION_TL_DELAY");

        vm.startBroadcast();
        timelock = new PerihelionTimelock(owners, threshold, delay);
        vm.stopBroadcast();

        console2.log("PerihelionTimelock:", address(timelock));
        console2.log("  owners:", owners.length);
        console2.log("  threshold:", threshold);
        console2.log("  delay (s):", delay);
    }
}
