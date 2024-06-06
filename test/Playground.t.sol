// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

contract Playground is Test {
    function testFindTopicName() public {
        // packet topic:
        bytes32 topic = keccak256("Packet(bytes)");
        console2.log("topic");
        console2.logBytes32(topic);
        assertEq(
            topic,
            bytes32(
                0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82
            )
        );
    }

    // Define a struct to match the layout of the packet
    struct Packet {
        uint64 nonce;
        uint16 localChainId;
        address ua;
        uint16 dstChainId;
        bytes32 dstAddress;
        bytes payload;
    }

    function testUnpack() public pure {
        //bytes
        //    memory packet = hex"000000000028d1f4006f701a95707a0290ac8b90b3719e8ee5b210360883006e352d8275aae3e0c2404d9f68f6cee084b5beb3dd000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000ea600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003fb5bd35b5300000000000000000000000000000000000000000000000000000000002410d80000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000544000000000000000000000000000000000000000000000000000000000024166200000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000014ecc19e177d24551aa7ed6bc6fe566eca726cc8a900000000000000000000000000000000000000000000000000000000000000000000000000000000000002e80000000000000000000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c000000000000000000000000000000000000000000000000000000000000008000000000000000000000000013aa49bac059d709dd0a18d6bb63290076a702d7000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000a11ce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000060000000000000000000000000d6bbde9174b1cdaa358d2cf4d57d1a9f7178fbff00000000000000000000000000000000000000000000000000000000000a11ce000000000000000000000000000000000000000000000000000000000024166200000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000ff970a61a04b1ca14834a43f5de4533ebddb5cc80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000002b82af49447d8a07e3bd95bd0d56f35241523fbab1000064ff970a61a04b1ca14834a43f5de4533ebddb5cc8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002476e98d330000000000000000000000000000000000000000000000000000000000000b0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        bytes
            memory packet = hex"0000000000000001006f30e3f07ccf272eb63b954cac9c915a6c3e440ae8006eecaaa12bf90e77d8596e01dd363f182dfcab029101000000000000000000000000fa085341ae8b7d3bce22a37570f6675fb09dd7b209935f581f0500000000000000000000000000005a3e6e96e0259237eb77362acb39d16aeb8c47e500000000002059400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a48f3ec33bd8dd7860c1acfea45118a4752ab9330000000000000000000000004ffffab8ab0a2070b26ef3a424aaafef96c46538000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001c4be906637000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009935f581f05000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fd92d36aadf0103b5b012d6a8013fbf9857d27ef0000000000000000000000000000000000000000000000000000000000000b0b000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000009935f581f05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        uint64 nonce;
        assembly {
            // Load the first 64 bits (8 bytes) from the packet into first64Bits
            mstore(nonce, mload(add(packet, 0x40)))
        }

        console2.log("nonce", nonce);
        //console2.log("localChainId", localChainId);
        //console2.log("ua", ua);
        //console2.log("dstChainId", dstChainId);
        //console2.log("dstAddress");
        //console2.logBytes(dstAddress);
        //console2.log("payload");
        //console2.logBytes(payload);
    }
}
