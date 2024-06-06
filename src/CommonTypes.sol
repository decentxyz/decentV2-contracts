// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct SwapInstructions {
    uint8 swapperId;
    bytes swapPayload;
}

struct FeeData {
    bytes4 appId;
    bytes4 affiliateId;
    uint bridgeFee;
    Fee[] appFees;
}

struct Fee {
    address recipient;
    address token;
    uint amount;
}

struct SwapAndExecuteInstructions {
    SwapInstructions swapInstructions;
    address target;
    address paymentOperator;
    address refund;
    bytes payload;
}

struct BridgeInstructions {
    SwapInstructions preBridge;
    SwapInstructions postBridge;
    uint8 bridgeId;
    uint256 dstChainId;
    address target;
    address paymentOperator;
    address refund;
    bytes payload;
    bytes additionalArgs;
}
