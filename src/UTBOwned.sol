// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Roles} from "decent-bridge/src/utils/Roles.sol";

contract UTBOwned is Roles {
    address payable public utb;

    constructor() Roles(msg.sender) {}

    /**
     * @dev Limit access to the approved UTB.
     */
    modifier onlyUtb() {
        require(msg.sender == utb, "Only utb");
        _;
    }

    /**
     * @dev Sets the approved UTB.
     * @param _utb The address of the UTB.
     */
    function setUtb(address _utb) public onlyAdmin {
        utb = payable(_utb);
    }
}
