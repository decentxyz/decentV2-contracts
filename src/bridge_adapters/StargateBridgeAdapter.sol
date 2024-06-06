// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IUTB} from "../interfaces/IUTB.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {SwapInstructions} from "../CommonTypes.sol";
import {SwapParams} from "../swappers/SwapParams.sol";
import {IStargateRouter, LzBridgeData} from "./stargate/IStargateRouter.sol";
import {IStargateReceiver} from "./stargate/IStargateReceiver.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

// pool ids: https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
// chain ids: https://stargateprotocol.gitbook.io/stargate/developers/chain-ids

contract StargateBridgeAdapter is
    BaseAdapter,
    IBridgeAdapter,
    IStargateReceiver
{
    uint8 public constant BRIDGE_ID = 1;
    uint8 public constant SG_FEE_BPS = 6;
    mapping(uint256 => address) public destinationBridgeAdapter;
    mapping(uint256 => uint16) public lzIdLookup;
    mapping(uint16 => uint256) public chainIdLookup;

    constructor() BaseAdapter() {}

    IStargateRouter public router;

    function setRouter(address _router) public onlyAdmin {
        router = IStargateRouter(_router);
    }

    function getId() public pure returns (uint8) {
        return BRIDGE_ID;
    }

    function registerRemoteBridgeAdapter(
        uint256 dstChainId,
        uint16 dstLzId,
        address decentBridgeAdapter
    ) public onlyAdmin {
        lzIdLookup[dstChainId] = dstLzId;
        chainIdLookup[dstLzId] = dstChainId;
        destinationBridgeAdapter[dstChainId] = decentBridgeAdapter;
    }

    function getBridgeToken(
        bytes calldata additionalArgs
    ) external pure returns (address bridgeToken) {
        bridgeToken = abi.decode(additionalArgs, (address));
    }

    function getBridgedAmount(
        uint256 amt2Bridge,
        address /*preBridgeToken*/,
        address /*postBridgeToken*/,
        bytes calldata additionalArgs
    ) external pure returns (uint256) {
        return (amt2Bridge * (100_00 - getSlippage(additionalArgs) - SG_FEE_BPS)) / 100_00;
    }

    function bridge(
        uint256 amt2Bridge,
        SwapInstructions memory postBridge,
        uint256 dstChainId,
        address target,
        address paymentOperator,
        bytes memory payload,
        bytes calldata additionalArgs,
        address refund
    ) public payable onlyUtb returns (bytes memory bridgePayload) {
        address bridgeToken = abi.decode(additionalArgs, (address));

        bridgePayload = abi.encode(
            postBridge,
            target,
            paymentOperator,
            payload,
            payable(refund)
        );

        if ( bridgeToken != address(0) ) {
            SafeERC20.safeTransferFrom(
                IERC20(bridgeToken),
                msg.sender,
                address(this),
                amt2Bridge
            );
            SafeERC20.forceApprove(IERC20(bridgeToken), address(router), amt2Bridge);
        }

        callBridge(
            amt2Bridge,
            dstChainId,
            bridgePayload,
            additionalArgs,
            refund
        );
    }

    function getValue(
        bytes calldata additionalArgs,
        uint256 amt2Bridge
    ) private pure returns (uint value) {
        (address bridgeToken, LzBridgeData memory lzBridgeData) = abi.decode(
            additionalArgs,
            (address, LzBridgeData)
        );
        return bridgeToken == address(0)
            ? (lzBridgeData.fee + amt2Bridge)
            : lzBridgeData.fee;
    }

    function getLzTxObj(
        bytes calldata additionalArgs
    ) private pure returns (IStargateRouter.lzTxObj memory) {
        (, , IStargateRouter.lzTxObj memory lzTxObj) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzTxObj;
    }

    function getSlippage(
        bytes calldata additionalArgs
    ) private pure returns (uint16) {
        (, , , uint16 slippage) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj, uint16)
        );
        return slippage;
    }

    function getDstChainId(
        bytes calldata additionalArgs
    ) private pure returns (uint16) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._dstChainId;
    }

    function getSrcPoolId(
        bytes calldata additionalArgs
    ) private pure returns (uint120) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._srcPoolId;
    }

    function getDstPoolId(
        bytes calldata additionalArgs
    ) private pure returns (uint120) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._dstPoolId;
    }

    function getDestAdapter(uint chainId) private view returns (address dstAddr) {
        dstAddr = destinationBridgeAdapter[chainId];

        if (dstAddr == address(0)) revert NoDstBridge();
    }

    function callBridge(
        uint256 amt2Bridge,
        uint256 dstChainId,
        bytes memory bridgePayload,
        bytes calldata additionalArgs,
        address refund
    ) private {
        router.swap{value: getValue(additionalArgs, amt2Bridge)}(
            getDstChainId(additionalArgs), //lzBridgeData._dstChainId, // send to LayerZero chainId
            getSrcPoolId(additionalArgs), //lzBridgeData._srcPoolId, // source pool id
            getDstPoolId(additionalArgs), //lzBridgeData._dstPoolId, // dst pool id
            payable(refund), // refund adddress. extra gas (if any) is returned to this address
            amt2Bridge, // quantity to swap
            (amt2Bridge * (100_00 - getSlippage(additionalArgs) - SG_FEE_BPS)) / 100_00, // the min qty you would accept on the destination, fee is 6 bips
            getLzTxObj(additionalArgs), // additional gasLimit increase, airdrop, at address
            abi.encodePacked(getDestAdapter(dstChainId)),
            bridgePayload // bytes param, if you wish to send additional payload you can abi.encode() them here
        );
    }

    function sgReceive(
        uint16, // _srcChainid
        bytes memory, // _srcAddress
        uint256, // _nonce
        address tokenIn, // _token
        uint256 amountLD, // amountLD
        bytes memory payload
    ) external override onlyExecutor {
        (
            SwapInstructions memory postBridge,
            address target,
            address paymentOperator,
            bytes memory utbPayload,
            address payable refund
        ) = abi.decode(
                payload,
                (SwapInstructions, address, address, bytes, address)
            );

        SwapParams memory swapParams = abi.decode(
            postBridge.swapPayload,
            (SwapParams)
        );

        uint256 bridgeValue;
        if ( swapParams.tokenIn == address(0) ) {
            bridgeValue = swapParams.amountIn;
        } else {
            SafeERC20.forceApprove(IERC20(swapParams.tokenIn), utb, swapParams.amountIn);
        }

        try IUTB(utb).receiveFromBridge{value: bridgeValue}(
            postBridge,
            target,
            paymentOperator,
            utbPayload,
            refund,
            BRIDGE_ID
        ) {
            if ( amountLD > swapParams.amountIn ) {
                _refundUser(refund, tokenIn, amountLD - swapParams.amountIn);
            }
        } catch (bytes memory) {
            _refundUser(refund, tokenIn, amountLD);
        }
    }

    function _refundUser(address user, address token, uint amount) private {
        if ( token == address(0) ) {
            (bool success, ) = user.call{value: amount}("");
            require(success);
        } else {
            SafeERC20.safeTransfer(IERC20(token), user, amount);
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
