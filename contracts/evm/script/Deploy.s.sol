// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { PerihelionEscrow } from "../src/PerihelionEscrow.sol";

/// @notice Deploys the Perihelion escrow and wires its guardian/owner.
/// @dev Configure before running:
///        PERIHELION_ENDPOINT     - LayerZero endpoint address
///        PERIHELION_STELLAR_EID  - LayerZero endpoint id of the Stellar settlement
///        PERIHELION_STELLAR_PEER (optional) - 32-byte Stellar settlement peer
///        PERIHELION_GUARDIAN     (optional) - emergency-pause guardian address
///        PERIHELION_OWNER        (optional) - new owner (the timelock); ownership
///                                  transfer is two-step, so the new owner must
///                                  call acceptOwnership() afterwards.
///      forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
contract Deploy is Script {
    function run() external returns (PerihelionEscrow escrow) {
        address endpoint = vm.envAddress("PERIHELION_ENDPOINT");
        uint32 stellarEid = uint32(vm.envUint("PERIHELION_STELLAR_EID"));
        bytes32 stellarPeer = vm.envOr("PERIHELION_STELLAR_PEER", bytes32(0));
        address guardian = vm.envOr("PERIHELION_GUARDIAN", address(0));
        address newOwner = vm.envOr("PERIHELION_OWNER", address(0));

        vm.startBroadcast();
        escrow = new PerihelionEscrow(endpoint, stellarEid);
        if (stellarPeer != bytes32(0)) {
            escrow.setPeer(stellarPeer);
        }
        if (guardian != address(0)) {
            escrow.setGuardian(guardian);
        }
        // Initiate the handover to the timelock. The timelock completes it by
        // executing escrow.acceptOwnership() through its governance flow.
        if (newOwner != address(0)) {
            escrow.transferOwnership(newOwner);
        }
        vm.stopBroadcast();

        console2.log("PerihelionEscrow:", address(escrow));
        console2.log("  guardian:", guardian);
        console2.log("  pendingOwner:", newOwner);
    }
}
