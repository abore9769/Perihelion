// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "./IERC20.sol";

/// @title Perihelion Escrow
/// @notice Source-chain leg of the Perihelion bridge. A winning solver locks a
///         user's funds against the user's signed intent; the funds are released
///         to the solver once the Stellar settlement is confirmed via LayerZero,
///         or refunded to the user after the deadline if settlement never lands.
/// @dev EIP-712 domain matches `@perihelion/sdk` exactly (name + version only),
///      so an intent signed by the SDK verifies here without re-signing.
contract PerihelionEscrow {
    /// @notice The user's signed cross-chain intent.
    struct Intent {
        address user;
        string destination; // Stellar address
        uint256 sourceChainId;
        address sourceAsset;
        uint256 sourceAmount;
        string destAsset; // Stellar asset id
        uint256 minDestAmount;
        uint256 deadline;
        uint256 nonce;
        address preferredSolver;
    }

    /// @notice A locked escrow position awaiting settlement or refund.
    struct Lock {
        address solver;
        address user;
        address asset;
        uint256 amount;
        uint256 deadline;
        bool released;
        bool refunded;
    }

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version)");

    bytes32 private constant INTENT_TYPEHASH = keccak256(
        "Intent(address user,string destination,uint256 sourceChainId,address sourceAsset,uint256 sourceAmount,string destAsset,uint256 minDestAmount,uint256 deadline,uint256 nonce,address preferredSolver)"
    );

    /// @notice EIP-712 domain separator (name="Perihelion", version="1").
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @notice Trusted LayerZero endpoint permitted to confirm settlement.
    address public immutable endpoint;

    /// @notice intentHash => escrow position.
    mapping(bytes32 => Lock) public locks;

    event Locked(
        bytes32 indexed intentHash,
        address indexed solver,
        address indexed user,
        address asset,
        uint256 amount,
        string destination,
        string destAsset
    );
    event Released(bytes32 indexed intentHash, address indexed solver, uint256 amount);
    event Refunded(bytes32 indexed intentHash, address indexed user, uint256 amount);

    error AlreadyLocked();
    error NotLocked();
    error InvalidSignature();
    error IntentExpired();
    error NotEndpoint();
    error ReservedForSolver();
    error AlreadyFinalized();
    error DeadlineNotPassed();
    error TransferFailed();

    constructor(address _endpoint) {
        endpoint = _endpoint;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Perihelion")),
                keccak256(bytes("1"))
            )
        );
    }

    /// @notice Solver claims an intent by locking the user's funds against it.
    /// @dev The user must have approved this contract for `sourceAmount` of
    ///      `sourceAsset`. Emits {Locked}, which the relayer turns into the
    ///      LayerZero message instructing the Soroban contract to release funds.
    function lock(Intent calldata intent, bytes calldata signature) external {
        if (block.timestamp >= intent.deadline) revert IntentExpired();
        if (
            intent.preferredSolver != address(0) && intent.preferredSolver != msg.sender
        ) revert ReservedForSolver();

        bytes32 intentHash = hashIntent(intent);
        if (locks[intentHash].user != address(0)) revert AlreadyLocked();
        if (!_verify(intentHash, intent.user, signature)) revert InvalidSignature();

        locks[intentHash] = Lock({
            solver: msg.sender,
            user: intent.user,
            asset: intent.sourceAsset,
            amount: intent.sourceAmount,
            deadline: intent.deadline,
            released: false,
            refunded: false
        });

        _pull(intent.sourceAsset, intent.user, intent.sourceAmount);

        emit Locked(
            intentHash,
            msg.sender,
            intent.user,
            intent.sourceAsset,
            intent.sourceAmount,
            intent.destination,
            intent.destAsset
        );
    }

    /// @notice Release locked funds to the solver after confirmed Stellar
    ///         settlement. Callable only by the trusted endpoint.
    function release(bytes32 intentHash) external {
        if (msg.sender != endpoint) revert NotEndpoint();
        Lock storage l = locks[intentHash];
        if (l.user == address(0)) revert NotLocked();
        if (l.released || l.refunded) revert AlreadyFinalized();

        l.released = true;
        _push(l.asset, l.solver, l.amount);
        emit Released(intentHash, l.solver, l.amount);
    }

    /// @notice Refund the user if the deadline passed without settlement.
    function refund(bytes32 intentHash) external {
        Lock storage l = locks[intentHash];
        if (l.user == address(0)) revert NotLocked();
        if (l.released || l.refunded) revert AlreadyFinalized();
        if (block.timestamp < l.deadline) revert DeadlineNotPassed();

        l.refunded = true;
        _push(l.asset, l.user, l.amount);
        emit Refunded(intentHash, l.user, l.amount);
    }

    /// @notice Compute the EIP-712 hash for an intent (its protocol-wide id).
    function hashIntent(Intent calldata intent) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                INTENT_TYPEHASH,
                intent.user,
                keccak256(bytes(intent.destination)),
                intent.sourceChainId,
                intent.sourceAsset,
                intent.sourceAmount,
                keccak256(bytes(intent.destAsset)),
                intent.minDestAmount,
                intent.deadline,
                intent.nonce,
                intent.preferredSolver
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function _verify(bytes32 digest, address signer, bytes calldata signature)
        private
        pure
        returns (bool)
    {
        if (signature.length != 65) return false;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        address recovered = ecrecover(digest, v, r, s);
        return recovered != address(0) && recovered == signer;
    }

    function _pull(address asset, address from, uint256 amount) private {
        bool ok = IERC20(asset).transferFrom(from, address(this), amount);
        if (!ok) revert TransferFailed();
    }

    function _push(address asset, address to, uint256 amount) private {
        bool ok = IERC20(asset).transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
