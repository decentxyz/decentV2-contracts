// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUTBFeeManager} from "./interfaces/IUTBFeeManager.sol";
import {SwapInstructions, BridgeInstructions} from "./CommonTypes.sol";
import {Roles} from "decent-bridge/src/utils/Roles.sol";

contract UTBFeeManager is IUTBFeeManager, Roles {
    address public signer;
    string constant BANNER = "\x19Ethereum Signed Message:\n32";

    constructor() Roles(msg.sender) {}

    /// @inheritdoc IUTBFeeManager
    function setSigner(address _signer) public onlyAdmin {
        signer = _signer;
    }

    /// @inheritdoc IUTBFeeManager
    function verifySignature(
        bytes memory packedInfo,
        bytes memory signature
    ) public view {
        bytes32 constructedHash = keccak256(
            abi.encodePacked(BANNER, keccak256(packedInfo))
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recovered = ecrecover(constructedHash, v, r, s);
        if (recovered != signer) revert WrongSig();
    }

        /**
     * @dev Splits an Ethereum signature into its components (r, s, v).
     * @param signature The Ethereum signature.
     */
    function splitSignature(
        bytes memory signature
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (signature.length != 65) revert WrongSigLength();

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
}
