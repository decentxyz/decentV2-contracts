// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IUTBFeeManager {

    /// @notice Thrown if incorrect signature
    error WrongSig();

    /// @notice Thrown if sig length != 65
    error WrongSigLength();

    /**
     * @dev Verifies packed info containing fees in either native or ERC20.
     * @param packedInfo The fees and swap instructions used to generate the signature.
     * @param signature The ECDSA signature to verify the fee structure.
     */
    function verifySignature(
      bytes memory packedInfo,
      bytes memory signature
    ) external;

    /**
     * @dev Sets the signer used for fee verification.
     * @param _signer The address of the signer.
     */
    function setSigner(address _signer) external;
}
