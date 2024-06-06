pragma solidity ^0.8.0;

import {SwapParams} from "../swappers/SwapParams.sol";

interface ISwapper {
    error RouterNotSet();

    function getId() external returns (uint8);

    function swap(
        bytes memory swapPayload
    ) external returns (address tokenOut, uint256 amountOut);

    function updateSwapParams(
        SwapParams memory newSwapParams,
        bytes memory payload
    ) external returns (bytes memory);
}
