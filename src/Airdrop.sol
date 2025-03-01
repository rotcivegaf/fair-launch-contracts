// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Owned} from "solmate/auth/Owned.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Airdrop is Owned {
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct AirdropRequest {
        address user;
        address token;
    }

    bytes32 constant AIRDROP_REQUEST_TYPEHASH = keccak256("AirdropRequest(address user,address token)");

    bytes32 public DOMAIN_SEPARATOR;
    address public signer;

    mapping(address => mapping(address => bool)) public hasClaimed;

    event AirdropClaimed(address indexed user, address indexed token, uint256 amount);

    constructor(address _signer) Owned(msg.sender) {
        signer = _signer;
        DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function claimAirdrop(address token, bytes memory signature) external {
        address user = msg.sender;
        require(!hasClaimed[token][user], "Airdrop already claimed");

        AirdropRequest memory req = AirdropRequest({
            user: user,
            token: token
        });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                hashAirdropRequest(req)
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == signer, "Invalid signature");

        hasClaimed[token][user] = true;

        uint256 amount = 1 ether; // Define the airdrop amount
        // @audit valid erc20
        require(IERC20(token).transfer(user, amount), "Token transfer failed");

        emit AirdropClaimed(user, token, amount);
    }

    function hashAirdropRequest(AirdropRequest memory req) internal pure returns (bytes32) {
        return keccak256(abi.encode(AIRDROP_REQUEST_TYPEHASH, req.user, req.token));
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Airdrop")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
