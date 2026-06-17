// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { PerihelionEscrow } from "../src/PerihelionEscrow.sol";
import { IERC20 } from "../src/IERC20.sol";

/// @dev Minimal mintable ERC-20 for tests.
contract MockERC20 is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract PerihelionEscrowTest is Test {
    PerihelionEscrow internal escrow;
    MockERC20 internal token;
    address internal endpoint = address(0xE9D);
    address internal solver = address(0x5012E5);

    uint256 internal userPk = 0xA11CE;
    address internal user;

    function setUp() public {
        escrow = new PerihelionEscrow(endpoint);
        token = new MockERC20();
        user = vm.addr(userPk);

        token.mint(user, 1_000_000);
        vm.prank(user);
        token.approve(address(escrow), type(uint256).max);
    }

    function _intent() internal view returns (PerihelionEscrow.Intent memory) {
        return PerihelionEscrow.Intent({
            user: user,
            destination: "GUSERSTELLAR",
            sourceChainId: block.chainid,
            sourceAsset: address(token),
            sourceAmount: 100_000,
            destAsset: "USDC:GA5Z",
            minDestAmount: 990_000,
            deadline: block.timestamp + 600,
            nonce: 1,
            preferredSolver: address(0)
        });
    }

    function _sign(PerihelionEscrow.Intent memory intent) internal view returns (bytes memory) {
        bytes32 digest = escrow.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_LockPullsFundsAndEmits() public {
        PerihelionEscrow.Intent memory intent = _intent();
        bytes memory sig = _sign(intent);

        vm.prank(solver);
        escrow.lock(intent, sig);

        assertEq(token.balanceOf(address(escrow)), 100_000);
        assertEq(token.balanceOf(user), 900_000);
    }

    function test_ReleaseToSolverByEndpoint() public {
        PerihelionEscrow.Intent memory intent = _intent();
        bytes memory sig = _sign(intent);
        bytes32 h = escrow.hashIntent(intent);

        vm.prank(solver);
        escrow.lock(intent, sig);

        vm.prank(endpoint);
        escrow.release(h);

        assertEq(token.balanceOf(solver), 100_000);
    }

    function test_RevertWhen_NonEndpointReleases() public {
        PerihelionEscrow.Intent memory intent = _intent();
        bytes memory sig = _sign(intent);
        bytes32 h = escrow.hashIntent(intent);

        vm.prank(solver);
        escrow.lock(intent, sig);

        vm.expectRevert(PerihelionEscrow.NotEndpoint.selector);
        escrow.release(h);
    }

    function test_RefundAfterDeadline() public {
        PerihelionEscrow.Intent memory intent = _intent();
        bytes memory sig = _sign(intent);
        bytes32 h = escrow.hashIntent(intent);

        vm.prank(solver);
        escrow.lock(intent, sig);

        vm.warp(intent.deadline + 1);
        escrow.refund(h);
        assertEq(token.balanceOf(user), 1_000_000);
    }

    function test_RevertWhen_BadSignature() public {
        PerihelionEscrow.Intent memory intent = _intent();
        bytes memory sig = _sign(intent);
        intent.sourceAmount = 200_000; // tamper after signing

        vm.prank(solver);
        vm.expectRevert(PerihelionEscrow.InvalidSignature.selector);
        escrow.lock(intent, sig);
    }
}
