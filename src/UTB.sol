// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Roles} from "decent-bridge/src/utils/Roles.sol";
import {SwapParams} from "./swappers/SwapParams.sol";
import {IUTB} from "./interfaces/IUTB.sol";
import {IUTBExecutor} from "./interfaces/IUTBExecutor.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "decent-bridge/src/interfaces/IWETH.sol";
import {IUTBFeeManager} from "./interfaces/IUTBFeeManager.sol";
import {IBridgeAdapter} from "./interfaces/IBridgeAdapter.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";
import {SwapInstructions, FeeData, Fee, BridgeInstructions, SwapAndExecuteInstructions} from "./CommonTypes.sol";


contract UTB is IUTB, Roles {
    constructor() Roles(msg.sender) {}

    IUTBExecutor public executor;
    IUTBFeeManager public feeManager;
    IWETH public wrapped;
    mapping(uint8 => address) public swappers;
    mapping(uint8 => address) public bridgeAdapters;
    bool public isActive = true;

    /**
     * @dev only support calling swapAndExecute and bridgeAndExecute if active
     */
    modifier isUtbActive() {
        if (!isActive) revert UTBPaused();
        _;
    }

    /**
     * @dev Transfers fees from the sender to the fee recipients.
     * @param feeData The bridge fee in native, as well as utb fee tokens and amounts.
     * @param packedInfo The fees and swap instructions which were used to generate the signature.
     * @param signature The ECDSA signature to verify the fee structure.
     */
    function _retrieveAndCollectFees(
        FeeData calldata feeData,
        bytes memory packedInfo,
        bytes calldata signature
    ) private returns (uint256 value) {
        if (address(feeManager) != address(0)) {
            feeManager.verifySignature(packedInfo, signature);
            value += feeData.bridgeFee;
            Fee[] memory fees = feeData.appFees;
            for (uint i = 0; i < fees.length; i++) {
                Fee memory fee = fees[i];
                if (fee.token != address(0)) {
                    SafeERC20.safeTransferFrom(
                        IERC20(fee.token),
                        msg.sender,
                        fee.recipient,
                        fee.amount
                    );
                } else {
                    (bool success, ) = address(fee.recipient).call{value: fee.amount}("");
                    value += fee.amount;
                    if (!success) revert ProtocolFeeCannotBeFetched();
                }
            }
        }
    }

    /**
     * @dev Refunds leftover native to the specified refund address.
     * @param to The address receiving the refund.
     * @param leftover The amount of leftover native.
     */
    function _refundLeftover(address to, uint256 leftover) internal {
        if (leftover > 0) {
            (bool success, ) = to.call{value: leftover}("");
            require(success, "failed to refund leftover");
        }
    }

    /**
     * @dev Sets the executor.
     * @param _executor The address of the executor.
     */
    function setExecutor(address _executor) public onlyAdmin {
        executor = IUTBExecutor(_executor);
    }

    /**
     * @dev Sets the wrapped native token.
     * @param _wrapped The address of the wrapped token.
     */
    function setWrapped(address _wrapped) public onlyAdmin {
        wrapped = IWETH(_wrapped);
    }

    /**
     * @dev Sets the fee manager.
     * @param _feeManager The address of the fee manager.
     */
    function setFeeManager(address _feeManager) public onlyAdmin {
        feeManager = IUTBFeeManager(_feeManager);
    }

    /**
     * @dev toggles active state
     */
    function toggleActive() public onlyAdmin {
        isActive = !isActive;
    }

    /**
     * @dev Performs a swap with the requested swapper and swap calldata.
     * @param swapInstructions The swapper ID and calldata to execute a swap.
     * @param retrieveTokenIn Flag indicating whether to transfer ERC20 for the swap.
     */
    function performSwap(
        SwapInstructions memory swapInstructions,
        bool retrieveTokenIn
    ) private returns (address tokenOut, uint256 amountOut, uint256 value) {
        ISwapper swapper = ISwapper(swappers[swapInstructions.swapperId]);

        SwapParams memory swapParams = abi.decode(
            swapInstructions.swapPayload,
            (SwapParams)
        );

        if (swapParams.tokenIn == address(0)) {
            if (msg.value < swapParams.amountIn) revert NotEnoughNative();
            wrapped.deposit{value: swapParams.amountIn}();
            value += swapParams.amountIn;
            swapParams.tokenIn = address(wrapped);
            swapInstructions.swapPayload = swapper.updateSwapParams(
                swapParams,
                swapInstructions.swapPayload
            );
        } else if (retrieveTokenIn) {
            SafeERC20.safeTransferFrom(
                IERC20(swapParams.tokenIn),
                msg.sender,
                address(this),
                swapParams.amountIn
            );
        }

        SafeERC20.forceApprove(
            IERC20(swapParams.tokenIn),
            address(swapper),
            swapParams.amountIn
        );

        (tokenOut, amountOut) = swapper.swap(swapInstructions.swapPayload);

        if (tokenOut == address(0)) {
            wrapped.withdraw(amountOut);
        }
    }

    /// @inheritdoc IUTB
    function swapAndExecute(
        SwapAndExecuteInstructions calldata instructions,
        FeeData calldata feeData,
        bytes calldata signature
    )
        public
        payable
        isUtbActive
    {
        uint256 value = _retrieveAndCollectFees(feeData, abi.encode(instructions, feeData), signature);
        value += _swapAndExecute(
            instructions.swapInstructions,
            instructions.target,
            instructions.paymentOperator,
            instructions.payload,
            instructions.refund
        );
        _refundLeftover(instructions.refund, msg.value - value);
        emit Swapped();
    }

    /**
     * @dev Swaps currency from the incoming to the outgoing token and executes a transaction with payment.
     * @param swapInstructions The swapper ID and calldata to execute a swap.
     * @param target The address of the target contract for the payment transaction.
     * @param paymentOperator The operator address for payment transfers requiring ERC20 approvals.
     * @param payload The calldata to execute the payment transaction.
     * @param refund The account receiving any refunds, typically the EOA which initiated the transaction.
     */
    function _swapAndExecute(
        SwapInstructions memory swapInstructions,
        address target,
        address paymentOperator,
        bytes memory payload,
        address refund
    ) private returns (uint256 value) {
        address tokenOut;
        uint256 amountOut;
        (tokenOut, amountOut, value) = performSwap(swapInstructions, true);
        if (tokenOut == address(0)) {
            executor.execute{value: amountOut}(
                target,
                paymentOperator,
                payload,
                tokenOut,
                amountOut,
                refund
            );
        } else {
            SafeERC20.forceApprove(IERC20(tokenOut), address(executor), amountOut);
            executor.execute(
                target,
                paymentOperator,
                payload,
                tokenOut,
                amountOut,
                refund
            );
        }
    }

    /**
     * @dev Performs the pre bridge swap and modifies the post bridge swap to utilize the bridged amount.
     * @param instructions The bridge data, token swap data, and payment transaction payload.
     */
    function swapAndModifyPostBridge(
        BridgeInstructions memory instructions
    )
        private
        returns (
            uint256 amount2Bridge,
            BridgeInstructions memory updatedInstructions,
            uint256 value
        )
    {
        address tokenOut;
        uint256 amountOut;
        (tokenOut, amountOut, value) = performSwap(
            instructions.preBridge, true
        );

        SwapParams memory newPostSwapParams = abi.decode(
            instructions.postBridge.swapPayload,
            (SwapParams)
        );

        newPostSwapParams.amountIn = IBridgeAdapter(
            bridgeAdapters[instructions.bridgeId]
        ).getBridgedAmount(amountOut, tokenOut, newPostSwapParams.tokenIn, instructions.additionalArgs);

        updatedInstructions = instructions;

        updatedInstructions.postBridge.swapPayload = ISwapper(swappers[
            instructions.postBridge.swapperId
        ]).updateSwapParams(
            newPostSwapParams,
            instructions.postBridge.swapPayload
        );

        amount2Bridge = amountOut;
    }

    /**
     * @dev Checks if the bridge token is native, and approves the bridge adapter to transfer ERC20 if required.
     * @param instructions The bridge data, token swap data, and payment transaction payload.
     * @param amt2Bridge The amount of the bridge token being transferred to the bridge adapter.
     */
    function approveAndCheckIfNative(
        BridgeInstructions memory instructions,
        uint256 amt2Bridge
    ) private returns (bool) {
        IBridgeAdapter bridgeAdapter = IBridgeAdapter(bridgeAdapters[instructions.bridgeId]);
        address bridgeToken = bridgeAdapter.getBridgeToken(
            instructions.additionalArgs
        );
        if (bridgeToken != address(0)) {
            SafeERC20.forceApprove(IERC20(bridgeToken), address(bridgeAdapter), amt2Bridge);
            return false;
        }
        return true;
    }

    /// @inheritdoc IUTB
    function bridgeAndExecute(
        BridgeInstructions calldata instructions,
        FeeData calldata feeData,
        bytes calldata signature
    )
        public
        payable
        isUtbActive
        returns (bytes memory)
    {
        uint256 feeValue = _retrieveAndCollectFees(feeData, abi.encode(instructions, feeData), signature);

        (
            uint256 amt2Bridge,
            BridgeInstructions memory updatedInstructions,
            uint256 swapValue
        ) = swapAndModifyPostBridge(instructions);

        _refundLeftover(instructions.refund, msg.value - feeValue - swapValue);

        return callBridge(amt2Bridge, feeData.bridgeFee, updatedInstructions);
    }

    /**
     * @dev Calls the bridge adapter to bridge funds, and approves the bridge adapter to transfer ERC20 if required.
     * @param amt2Bridge The amount of the bridge token being bridged via the bridge adapter.
     * @param bridgeFee The fee being transferred to the bridge adapter and finally to the bridge.
     * @param instructions The bridge data, token swap data, and payment transaction payload.
     */
    function callBridge(
        uint256 amt2Bridge,
        uint bridgeFee,
        BridgeInstructions memory instructions
    ) private returns (bytes memory) {
        bool native = approveAndCheckIfNative(instructions, amt2Bridge);
        emit BridgeCalled();
        return
            IBridgeAdapter(bridgeAdapters[instructions.bridgeId]).bridge{
                value: bridgeFee + (native ? amt2Bridge : 0)
            }(
                amt2Bridge,
                instructions.postBridge,
                instructions.dstChainId,
                instructions.target,
                instructions.paymentOperator,
                instructions.payload,
                instructions.additionalArgs,
                instructions.refund
            );
    }

    /// @inheritdoc IUTB
    function receiveFromBridge(
        SwapInstructions memory postBridge,
        address target,
        address paymentOperator,
        bytes memory payload,
        address refund,
        uint8 bridgeId
    ) public payable {
        if (msg.sender != bridgeAdapters[bridgeId]) revert OnlyBridgeAdapter();
        emit RecievedFromBridge();
        _swapAndExecute(postBridge, target, paymentOperator, payload, refund);
    }

    /// @inheritdoc IUTB
    function registerSwapper(address swapper) public onlyAdmin {
        ISwapper s = ISwapper(swapper);
        swappers[s.getId()] = swapper;
    }

    /// @inheritdoc IUTB
    function registerBridge(address bridge) public onlyAdmin {
        IBridgeAdapter b = IBridgeAdapter(bridge);
        bridgeAdapters[b.getId()] = bridge;
    }

    receive() external payable {}

    fallback() external payable {}
}
