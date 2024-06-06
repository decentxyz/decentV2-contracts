// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {UTBOwned} from "../UTBOwned.sol";

contract BaseAdapter is UTBOwned {
    address public bridgeExecutor;

    constructor() UTBOwned() {}

    error OnlyExecutor();
    modifier onlyExecutor() {
        if (msg.sender != address(bridgeExecutor)) revert OnlyExecutor();
        _;
    }

    function setBridgeExecutor(address _executor) public onlyAdmin {
        bridgeExecutor = _executor;
    }
}
