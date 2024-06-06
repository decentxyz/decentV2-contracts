// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IUTBExecutor {

    /**
     * @dev Executes a payment transaction with native OR ERC20.
     * @param target The address of the target contract for the payment transaction.
     * @param paymentOperator The operator address for payment transfers requiring ERC20 approvals.
     * @param payload The calldata to execute the payment transaction.
     * @param token The token being transferred, zero address for native.
     * @param amount The amount of native or ERC20 being sent with the payment transaction.
     * @param refund The account receiving any refunds, typically the EOA that initiated the transaction.
     */
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint256 amount,
        address refund
    ) external payable;

    /**
     * @dev Executes a payment transaction with native AND/OR ERC20.
     * @param target The address of the target contract for the payment transaction.
     * @param paymentOperator The operator address for payment transfers requiring ERC20 approvals.
     * @param payload The calldata to execute the payment transaction.
     * @param token The token being transferred, zero address for native.
     * @param amount The amount of native or ERC20 being sent with the payment transaction.
     * @param refund The account receiving any refunds, typically the EOA that initiated the transaction.
     * @param extraNative Forwards additional gas or native fees required to executing the payment transaction.
     */
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint256 amount,
        address refund,
        uint256 extraNative
    ) external;
}
