// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUTBExecutor} from "./interfaces/IUTBExecutor.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Operable} from "decent-bridge/src/utils/Operable.sol";

contract UTBExecutor is IUTBExecutor, Operable {

    /// @inheritdoc IUTBExecutor
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint amount,
        address refund
    ) public payable onlyOperator {
        return
            execute(target, paymentOperator, payload, token, amount, refund, 0);
    }

    /// @inheritdoc IUTBExecutor
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint amount,
        address refund,
        uint extraNative
    ) public onlyOperator {
        bool success;
        if (token == address(0)) {
            (success, ) = target.call{value: amount}(payload);
            if (!success) {
                (payable(refund).call{value: amount}(""));
            }
            return;
        }

        uint initBalance = IERC20(token).balanceOf(address(this));

        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        SafeERC20.forceApprove(IERC20(token), paymentOperator, amount);

        if (extraNative > 0) {
            (success, ) = target.call{value: extraNative}(payload);
            if (!success) {
                (payable(refund).call{value: extraNative}(""));
            }
        } else {
            (success, ) = target.call(payload);
        }

        uint remainingBalance = IERC20(token).balanceOf(address(this)) -
            initBalance;

        if (remainingBalance == 0) {
            return;
        }

        SafeERC20.safeTransfer(IERC20(token), refund, remainingBalance);
    }
}
