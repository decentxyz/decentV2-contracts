// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {UTB, SwapInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../../src/UTB.sol";
import {UniSwapper} from "../../src/swappers/UniSwapper.sol";
import {SwapParams, SwapDirection} from "../../src/swappers/SwapParams.sol";
import {XChainExactOutFixture} from "../helpers/XChainExactOutFixture.sol";
import {VeryCoolCat} from "../helpers/VeryCoolCat.sol";

contract UTBFeeCollector is Test, XChainExactOutFixture {
    string chain;
    address weth;
    address usdc;
    uint nativeFee = 1 ether;
    uint usdcFee = 1e5;

    function setUp() public {
        setRuntime(ENV_FORGE_TEST);
        loadAllChainInfo();
        setupUsdcInfo();
        setupWethHelperInfo();
        loadAllUniRouterInfo();
        setSkipFile(true);
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        chain = arbitrum;
        weth = getWeth(chain);
        usdc = getUsdc(chain);
    }

    function testFees() public {
        VeryCoolCat cat = deployTheCat(chain);
        uint256 amount = cat.wethPrice();
        address payable refund = payable(alice);

        (
            UTB utb,
            /*UTBExecutor utbExecutor*/,
            UniSwapper swapper,
            /*DecentEthRouter decentRouter*/,
            /*DecentBridgeAdapter decentBridgeAdapter*/,
            /*StargateBridgeAdapter sgBridgeAdapte*/
        ) = deployUTBAndItsComponents(chain);

        SwapParams memory swapParams = SwapParams({
            tokenIn: address(0),
            amountIn: amount,
            tokenOut: getWeth(chain),
            amountOut: amount,
            direction: SwapDirection.EXACT_OUT,
            path: ""
        });

        SwapInstructions memory swapInstructions = SwapInstructions({
            swapperId: swapper.getId(),
            swapPayload: abi.encode(swapParams, address(utb), refund)
        });

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: swapInstructions,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithWeth, (alice))
        });

        FeeData memory feeData = _nativeAndUsdcFeeData();

        bytes memory signature = getSignature(abi.encode(swapAndExecInstructions, feeData));

        deal(alice, 1000 ether);
        mintUsdcTo(chain, alice, 1000e6);

        vm.startPrank(alice);

        ERC20(usdc).approve(address(utb), usdcFee);

        utb.swapAndExecute{value: amount + nativeFee}(
            swapAndExecInstructions,
            feeData,
            signature
        );

        uint nativeBalance = address(feeRecipientNative).balance;
        assertEq(nativeBalance, nativeFee);

        uint usdcBalance = ERC20(usdc).balanceOf(feeRecipientUsdc);
        assertEq(usdcBalance, usdcFee);
    }

    function _nativeAndUsdcFeeData() internal view returns (FeeData memory feeData) {
        Fee[] memory appFees = new Fee[](2);

        appFees[0] = Fee({
            recipient: feeRecipientNative,
            token: address(0),
            amount: nativeFee
        });

        appFees[1] = Fee({
            recipient: feeRecipientUsdc,
            token: usdc,
            amount: usdcFee
        });

        feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            appFees: appFees
        });
    }

    //function testValidateFee() public {
    //    uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    //    bytes32 hash = keccak256(abi.encodePacked(tokenIds, songSelections));
    //    console2.logBytes32(hash);

    //    bytes32 ethSignedHash = keccak256(abi.encodePacked(BANNER, hash));

    //    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
    //    bytes memory signature = abi.encodePacked(r, s, v);
    //}

    //function onTheReceiverSide() {
    //    bytes32 messageHash = keccak256(
    //        abi.encodePacked(tokenIds, songSelections)
    //    );

    //    bytes32 ethSignedHash = keccak256(
    //        abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    //    );

    //    address signer = recoverSigner(ethSignedHash, signature);
    //}
}
