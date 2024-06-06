// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// test fixture
import {ArbitrumFixture} from "./common/ArbitrumFixture.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/swappers/SwapParams.sol";

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";
import {UniswapperHelpers} from "./helpers/UniswapperHelpers.sol";

// stargate contracts
import {IStargateRouter, LzBridgeData} from "../src/bridge_adapters/stargate/IStargateRouter.sol";

import {VmSafe} from "forge-std/Vm.sol";
import {ILayerZeroEndpoint} from "LayerZero/interfaces/ILayerZeroEndpoint.sol";

interface IPool {
    function mint(address _to, uint256 _amountLD) external;
}

abstract contract MockEndpoint is ILayerZeroEndpoint {
    address public defaultReceiveLibraryAddress;
}

contract UTBStargateTest is Test, ArbitrumFixture {
    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;
    uint8 constant SG_FUNCTION_TYPE_SWAP_REMOTE = 1;
    uint16 constant SG_SLIPPAGE_BPS = 1_00;
    uint256 amount;
    uint256 amountToStargate;

    function setUp() public {
        cat = new VeryCoolCat();
        cat.setWeth(address(TEST.CONFIG.weth));
        refund = payable(TEST.EOA.alice);
        amount = cat.sgEthPrice();
        amountToStargate = (amount * (100_00 + SG_SLIPPAGE_BPS + TEST.SRC.stargateBridgeAdapter.SG_FEE_BPS())) / 100_00;
        deal(TEST.EOA.alice, 1000 ether);
        vm.startPrank(TEST.EOA.alice);
    }

    function test_bridgeAndExecute_stargate_with_slippage() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        // vm.recordLogs();

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );

        console2.log('bridge fee', feeData.bridgeFee);

        // deliverLzMessageAtDestination(GAS_TO_MINT);

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        // uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        // assertEq(nftBalance, 1);
    }

    function test_bridgeAndExecute_stargate_without_slippage() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = getBridgeAndExecuteParams(0); // slippage

        vm.expectRevert("Stargate: slippage too high");

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );
    }

    function getBridgeAndExecuteParams(uint16 slippage) private returns (
        BridgeInstructions memory bridgeInstructions,
        FeeData memory feeData,
        bytes memory signature
    ) {
        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.getId(),
                swapPayload: abi.encode(
                    SwapParams({
                        tokenIn: address(0),
                        amountIn: amountToStargate,
                        tokenOut: address(0),
                        amountOut: amountToStargate,
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
                        tokenIn: address(0),
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
            bridgeId: TEST.SRC.stargateBridgeAdapter.getId(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithSgEth, (TEST.EOA.alice)),
            additionalArgs: "" // abi.encode(TEST.CONFIG.stargateEth)
        });

        (uint256 lzNativeFee, ) = IStargateRouter(TEST.CONFIG.stargateComposer).quoteLayerZeroFee(
            TEST.CONFIG.dstLzId,
            SG_FUNCTION_TYPE_SWAP_REMOTE,
            abi.encodePacked(
                address(TEST.DST.stargateBridgeAdapter)
            ),
            abi.encode(
                bridgeInstructions.postBridge,
                address(cat),
                bridgeInstructions.payload,
                refund
            ),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            })
        );

        bridgeInstructions.additionalArgs = abi.encode(
            address(0),
            LzBridgeData({
                _srcPoolId: 13,
                _dstPoolId: 13,
                _dstChainId: TEST.CONFIG.dstLzId,
                _bridgeAddress: address(TEST.DST.stargateBridgeAdapter),
                fee: uint96((lzNativeFee * 140) / 100)
            }),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            }),
            slippage
        );

        feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: (lzNativeFee * 140) / 100,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        signature = getSignature(abi.encode(bridgeInstructions, feeData));
    }

    function getPacket() private returns (bytes memory) {
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("Packet(bytes)")) {
                console2.logBytes32(entries[i].topics[0]);
                console2.logBytes(entries[i].data);
                return entries[i].data;
            }
        }
        revert(string.concat("no packet was emitted"));
    }

    function extractLzInfo(
        bytes memory packet
    )
        private
        pure
        returns (
            uint64 nonce,
            uint16 localChainId,
            address sourceUa,
            uint16 dstChainId,
            address dstAddress
        )
    {
        assembly {
            let start := add(packet, 64)
            nonce := mload(add(start, 8))
            localChainId := mload(add(start, 10))
            sourceUa := mload(add(start, 30))
            dstChainId := mload(add(start, 32))
            dstAddress := mload(add(start, 52))
        }
    }

    function extractAppPayload(
        bytes memory packet
    ) private pure returns (bytes memory payload) {
        uint start = 64 + 52;
        uint payloadLength = packet.length - start;
        payload = new bytes(payloadLength);
        assembly {
            let payloadPtr := add(packet, start)
            let destPointer := add(payload, 32)
            for {
                let i := 32
            } lt(i, payloadLength) {
                i := add(i, 32)
            } {
                mstore(destPointer, mload(add(payloadPtr, i)))
                destPointer := add(destPointer, 32)
            }
        }
    }

    function deliverLzMessageAtDestination(
        uint gasLimit
    ) public {
        bytes memory packet = getPacket();
        (
            /*uint64 nonce*/,
            /*uint16 localChainId*/,
            address sourceUa,
            /*uint16 dstChainId*/,
            address dstAddress
        ) = extractLzInfo(packet);

        console2.log('sourceUa', sourceUa);
        console2.log('dstAddress', dstAddress);

        bytes memory payload = extractAppPayload(packet);
        console2.log('payload');
        console2.logBytes(payload);
        receiveLzMessage(sourceUa, dstAddress, gasLimit, payload);
    }

    function receiveLzMessage(
        address srcUa,
        address dstUa,
        uint gasLimit,
        bytes memory payload
    ) public {

        MockEndpoint dstEndpoint = MockEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        bytes memory srcPath = abi.encodePacked(dstUa, srcUa);

        uint64 nonce = dstEndpoint.getInboundNonce(TEST.CONFIG.dstLzId, srcPath);

        address defaultLibAddress = dstEndpoint.defaultReceiveLibraryAddress();

        vm.startPrank(defaultLibAddress);

        dstEndpoint.receivePayload(
            TEST.CONFIG.dstLzId, // src chain id
            srcPath, // src address
            dstUa, // dst address
            nonce + 1, // nonce
            gasLimit, // gas limit
            payload // payload
        );

        vm.stopPrank();
    }
}
