pragma solidity ^0.8.0;

import {SwapInstructions} from "../CommonTypes.sol";

interface IBridgeAdapter {

    error NoDstBridge();

    function getId() external returns (uint8);

    function getBridgeToken(
        bytes calldata additionalArgs
    ) external returns (address);

    function getBridgedAmount(
        uint256 amt2Bridge,
        address preBridgeToken,
        address postBridgeToken,
        bytes calldata additionalArgs
    ) external returns (uint256);

    function bridge(
        uint256 amt2Bridge,
        SwapInstructions memory postBridge,
        uint256 dstChainId,
        address target,
        address paymentOperator,
        bytes memory payload,
        bytes calldata additionalArgs,
        address refund
    ) external payable returns (bytes memory);
}
