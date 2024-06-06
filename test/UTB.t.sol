// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "./common/EthereumFixture.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/swappers/SwapParams.sol";

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";

contract UTBTest is Test, EthereumFixture {
    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;

    function setUp() public {
        cat = new VeryCoolCat();
        cat.setWeth(address(TEST.CONFIG.weth));
        refund = payable(TEST.EOA.alice);
        deal(TEST.EOA.alice, 1000 ether);
        vm.startPrank(TEST.EOA.alice);
    }

    function test_swapAndExecute_example() public {
        uint256 amount = cat.wethPrice();

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amount,
                        tokenOut: address(TEST.CONFIG.weth),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.SRC.utb),
                    refund
                )
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithWeth, (TEST.EOA.alice))
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);
    }

    function test_bridgeAndExecute_example() public {
        uint256 amount = cat.ethPrice();

        BridgeInstructions memory bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amount,
                        tokenOut: address(0),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.SRC.utb),
                    refund
                )
            }),
            postBridge: SwapInstructions({
                swapperId: TEST.DST.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(TEST.CONFIG.weth),
                        amountIn: amount,
                        tokenOut: address(0),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.DST.utb),
                    refund
                )
            }),
            bridgeId: TEST.SRC.decentBridgeAdapter.getId(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: abi.encode(GAS_TO_MINT)
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.decentBridgeAdapter.estimateFees(
            bridgeInstructions.postBridge,
            TEST.CONFIG.dstChainId,
            address(TEST.DST.decentBridgeAdapter),
            GAS_TO_MINT,
            abi.encodeCall(
                TEST.DST.decentBridgeAdapter.receiveFromBridge,
                (
                    bridgeInstructions.postBridge, // post bridge
                    address(cat), // target
                    address(cat), // paymentOperator
                    bridgeInstructions.payload, // payload
                    refund // refund
                )
            )
        );

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: lzNativeFee,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        TEST.SRC.utb.bridgeAndExecute{value: amount + nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);
    }

    function test_swapAndExecute_refunds_overpay() public {
        uint256 amount = cat.wethPrice();
        uint256 aliceBefore = TEST.EOA.alice.balance;

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amount,
                        tokenOut: address(TEST.CONFIG.weth),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.SRC.utb),
                    refund
                )
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithWeth, (TEST.EOA.alice))
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee + 1 ether}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amount - nativeFee);
    }

    function test_bridgeAndExecute_refunds_overpay() public {
        uint256 amount = cat.ethPrice();
        uint256 aliceBefore = TEST.EOA.alice.balance;

        BridgeInstructions memory bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amount,
                        tokenOut: address(0),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.SRC.utb),
                    refund
                )
            }),
            postBridge: SwapInstructions({
                swapperId: TEST.DST.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(TEST.CONFIG.weth),
                        amountIn: amount,
                        tokenOut: address(0),
                        amountOut: amount,
                        direction: SwapDirection.EXACT_OUT,
                        path: ""
                    }),
                    address(TEST.DST.utb),
                    refund
                )
            }),
            bridgeId: TEST.SRC.decentBridgeAdapter.getId(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: abi.encode(GAS_TO_MINT)
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.decentBridgeAdapter.estimateFees(
            bridgeInstructions.postBridge,
            TEST.CONFIG.dstChainId,
            address(TEST.DST.decentBridgeAdapter),
            GAS_TO_MINT,
            abi.encodeCall(
                TEST.DST.decentBridgeAdapter.receiveFromBridge,
                (
                    bridgeInstructions.postBridge, // post bridge
                    address(cat), // target
                    address(cat), // paymentOperator
                    bridgeInstructions.payload, // payload
                    refund // refund
                )
            )
        );

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: lzNativeFee,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        TEST.SRC.utb.bridgeAndExecute{value: amount + nativeFee + lzNativeFee + 1 ether}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amount - nativeFee - lzNativeFee);
    }

    function test_swapAndExecuteUSDT_refunds_overpay() public {
        address usdtMainnet = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        uint256 amountIn = cat.ethPrice();
        uint256 amountOut = cat.usdtPrice();
        cat.setUsdt(usdtMainnet);
        uint256 aliceBefore = TEST.EOA.alice.balance;

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amountIn,
                        tokenOut: usdtMainnet, // USDT
                        amountOut: amountOut,
                        direction: SwapDirection.EXACT_OUT,
                        path: abi.encodePacked(usdtMainnet, uint24(500), TEST.CONFIG.weth)
                    }),
                    address(TEST.SRC.utb),
                    refund
                )
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithUsdt, (TEST.EOA.alice))
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        TEST.SRC.utb.swapAndExecute{value: amountIn + nativeFee + 1 ether}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amountIn - nativeFee);
    }
}
