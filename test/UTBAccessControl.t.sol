// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {UTB, SwapInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {UTBExecutor} from "../src/UTBExecutor.sol";
import {UniSwapper} from "../src/swappers/UniSwapper.sol";
import {SwapParams, SwapDirection} from "../src/swappers/SwapParams.sol";
import {XChainExactOutFixture} from "./helpers/XChainExactOutFixture.sol";
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";
import {DecentBridgeAdapter} from "../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../src/bridge_adapters/StargateBridgeAdapter.sol";
import {DecentBridgeExecutor} from "decent-bridge/src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "decent-bridge/src/DecentEthRouter.sol";
import {DcntEth} from "decent-bridge/src/DcntEth.sol";

contract UTBAccessControl is Test, XChainExactOutFixture {
    UTB utb;
    UTBExecutor utbExecutor;
    UniSwapper swapper;
    DcntEth dcntEth;
    DecentEthRouter decentEthRouter;
    DecentBridgeExecutor decentBridgeExecutor;
    DecentBridgeAdapter decentBridgeAdapter;
    StargateBridgeAdapter stargateBridgeAdapter;
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

        (
            utb,
            utbExecutor,
            swapper,
            decentEthRouter,
            decentBridgeAdapter,
            stargateBridgeAdapter
        ) = deployUTBAndItsComponents(chain);
        dcntEth = DcntEth(address(decentEthRouter.dcntEth()));
        decentBridgeExecutor = DecentBridgeExecutor(payable(address(decentEthRouter.executor())));
    }

    function xChainPauseUTBSetup() public {
        dealTo(src, alice, initialEthBalance);
        mintUsdcTo(src, alice, initialUsdcBalance);
        mintWethTo(src, alice, initialEthBalance);
        utb = setupXChainUTBInfraReturnSrcUTB(src, dst);
        switchTo(src);
        utb.toggleActive();
        cat = deployTheCat(dst);
        catUsdcPrice = cat.price();
        catEthPrice = cat.ethPrice();
    }

    function testUtbReceiveFromBridge() public {
        (
            utb,
            /*UTBExecutor utbExecutor*/,
            swapper,
            /*DecentEthRouter decentRouter*/,
            /*DecentBridgeAdapter decentBridgeAdapter*/,
            /*StargateBridgeAdapter sgBridgeAdapte*/
        ) = deployUTBAndItsComponents(chain);

        SwapParams memory swapParams = SwapParams({
            tokenIn: address(0),
            amountIn: 1 ether,
            tokenOut: address(0),
            amountOut: 1 ether,
            direction: SwapDirection.EXACT_OUT,
            path: ""
        });

        uint8 swapperId = swapper.getId();

        SwapInstructions memory swapInstructions = SwapInstructions({
            swapperId: swapperId,
            swapPayload: abi.encode(swapParams, address(utb), address(0))
        });

        vm.expectRevert(bytes4(keccak256("OnlyBridgeAdapter()")));

        utb.receiveFromBridge(
            swapInstructions,
            address(0),
            address(0),
            "",
            payable(address(0)),
            swapperId
        );
    }

    function testUtbSetExecutor() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        utb.setExecutor(address(0));
        vm.stopPrank();
    }

    function testUtbSetWrapped() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        utb.setWrapped(payable(address(0)));
        vm.stopPrank();
    }

    function testUtbSetFeeManager() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        utb.setFeeManager(address(0));
        vm.stopPrank();
    }

    function testUtbRegisterSwapper() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        utb.registerSwapper(address(0));
        vm.stopPrank();
    }

    function testUtbRegisterBridge() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        utb.registerBridge(address(0));
        vm.stopPrank();
    }

    function testUtbExecutorExecute() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only operator'));
        utbExecutor.execute(
            address(0),
            address(0),
            "",
            address(0),
            0,
            payable(address(0))
        );
        vm.stopPrank();
    }

    function testUniSwapperSetWrapped() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        swapper.setWrapped(payable(address(0)));
        vm.stopPrank();
    }

    function testUniSwapperSetRouter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        swapper.setRouter(address(0));
        vm.stopPrank();
    }

    function testUniSwapperSwap() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only utb'));
        swapper.swap("");
        vm.stopPrank();
    }

    function testDecentBridgeAdapterSetRouter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        decentBridgeAdapter.setRouter(address(0));
        vm.stopPrank();
    }

    function testDecentBridgeAdapterRegisterRemoteBridgeAdapter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        decentBridgeAdapter.registerRemoteBridgeAdapter(0, 0, address(0));
        vm.stopPrank();
    }

    function testStargateBridgeAdapterSetRouter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        stargateBridgeAdapter.setRouter(address(0));
        vm.stopPrank();
    }

    function testStargetBridgeAdapterRegisterRemoteBridgeAdapter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        stargateBridgeAdapter.registerRemoteBridgeAdapter(0, 0, address(0));
        vm.stopPrank();
    }

    function testDcntEthSetRouter() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        dcntEth.setRouter(address(0));
        vm.stopPrank();
    }

    function testDcntEthMint() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only router'));
        dcntEth.mint(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthBurn() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only router'));
        dcntEth.burn(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthMintByAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        dcntEth.mintByAdmin(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthBurnByAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        dcntEth.burnByAdmin(address(0), 0);
        vm.stopPrank();
    }

    function testDecentEthRouterRegisterDcntEth() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        decentEthRouter.registerDcntEth(address(0));
        vm.stopPrank();
    }

    function testDecentEthRouterAddDestinationBridge() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        decentEthRouter.addDestinationBridge(0, address(0));
        vm.stopPrank();
    }

    function testDecentEthRouterSetRequireOperator() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only admin'));
        decentEthRouter.setRequireOperator(false);
        vm.stopPrank();
    }

    function testDecentBridgeExecutorExecute() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes('Only operator'));
        decentBridgeExecutor.execute(
            address(0),
            address(0),
            true,
            0,
            ""
        );
        vm.stopPrank();
    }

    function testRevertSwapAndExecuteIsNotActive() public {
        (
            utb,
            /*UTBExecutor executor*/,
            swapper,
            ,
            ,

        ) = deployUTBAndItsComponents(chain);
        utb.toggleActive();
        uint256 slippage = 1;

        cat = deployTheCat(chain);
        uint usdcOut = cat.price();

        (SwapParams memory swapParams,) = getSwapParamsExactOut(
            chain,
            weth,
            usdc,
            usdcOut,
            slippage
        );

        address payable refund = payable(alice);

        SwapInstructions memory swapInstructions = SwapInstructions({
            swapperId: swapper.getId(),
            swapPayload: abi.encode(swapParams, address(utb), refund)
        });

        mintWethTo(chain, alice, swapParams.amountIn);
        startImpersonating(alice);
        ERC20(weth).approve(address(utb), swapParams.amountIn);

        SwapAndExecuteInstructions
            memory instructions = SwapAndExecuteInstructions({
                swapInstructions: swapInstructions,
                target: address(cat),
                paymentOperator: address(cat),
                refund: refund,
                payload: abi.encodeCall(cat.mintWithUsdc, (bob))
            });

        (
            bytes memory signature,
            FeeData memory feeData
        ) = getFeesAndSignature(instructions);

        vm.expectRevert(bytes4(keccak256("UTBPaused()")));
        utb.swapAndExecute(instructions, feeData, signature);
        stopImpersonating();
    }

    function testFailBridgeAndExecuteIsNotActive() public {
        xChainPauseUTBSetup();
        performXChainExactOutAndReceiveDecentBridge(
            getXChainCatUSDCMintScenario(address(0), bob)
        );
    }
}
