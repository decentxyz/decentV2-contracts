// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// bridge contracts
import {DecentBridgeExecutor} from "../../lib/decent-bridge/src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "../../lib/decent-bridge/src/DecentEthRouter.sol";
import {DcntEth} from "../../lib/decent-bridge/src/DcntEth.sol";

// utb contracts
import {UTB} from "../../src/UTB.sol";
import {UTBExecutor} from "../../src/UTBExecutor.sol";
import {UTBFeeManager} from "../../src/UTBFeeManager.sol";
import {UniSwapper} from "../../src/swappers/UniSwapper.sol";
import {DecentBridgeAdapter} from "../../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../../src/bridge_adapters/StargateBridgeAdapter.sol";

// layer zero contracts
import {LZEndpointMock} from "./LZEndpointMock.sol";

// token contracts
import {WETH} from "solmate/tokens/WETH.sol";

contract BaseFixture is Test {

    TestInfo TEST;

    LZEndpointMock srcLzEndpoint;
    LZEndpointMock dstLzEndpoint;

    struct TestInfo {
        Config CONFIG;
        Deployment SRC;
        Deployment DST;
        Accounts EOA;
    }

    struct Config {
        string rpc;
        uint256 srcChainId;
        uint256 dstChainId;
        uint16 srcLzId;
        uint16 dstLzId;
        bool isGasEth;
        address weth;
        address uniswap;
        address stargateComposer;
        address stargateEth;
    }

    struct Deployment {
        DecentBridgeExecutor decentBridgeExecutor;
        DecentEthRouter decentEthRouter;
        DcntEth dcntEth;
        UTB utb;
        UTBExecutor utbExecutor;
        UTBFeeManager utbFeeManager;
        UniSwapper uniSwapper;
        DecentBridgeAdapter decentBridgeAdapter;
        StargateBridgeAdapter stargateBridgeAdapter;
    }

    struct Accounts {
        address deployer;
        address feeSigner;
        address alice;
        address bob;
    }

    constructor() {
        TEST.EOA.deployer = makeAddr("DEPLOYER");
        TEST.EOA.feeSigner = makeAddr("FEE_SIGNER");
        TEST.EOA.alice = makeAddr("ALICE");
        TEST.EOA.bob = makeAddr("BOB");
    }

    function initialize() internal {
        vm.createSelectFork(TEST.CONFIG.rpc);

        srcLzEndpoint = new LZEndpointMock(TEST.CONFIG.srcLzId);
        dstLzEndpoint = new LZEndpointMock(TEST.CONFIG.dstLzId);

        vm.startPrank(TEST.EOA.deployer);
        deal(TEST.EOA.deployer, 100 ether);

        TEST.SRC = deploy(srcLzEndpoint);
        TEST.DST = deploy(dstLzEndpoint);

        connect();
        liquify();

        vm.stopPrank();

        srcLzEndpoint.setDestLzEndpoint(address(TEST.DST.dcntEth), address(dstLzEndpoint));
        dstLzEndpoint.setDestLzEndpoint(address(TEST.SRC.dcntEth), address(srcLzEndpoint));
    }

    function deploy(
        LZEndpointMock lzEndpoint
    ) internal returns (Deployment memory deployment) {
        (
            DecentBridgeExecutor decentBridgeExecutor,
            DecentEthRouter decentEthRouter,
            DcntEth dcntEth
        ) = deployBridge(lzEndpoint);

        (
            UTB utb,
            UTBExecutor utbExecutor,
            UTBFeeManager utbFeeManager,
            UniSwapper uniSwapper,
            DecentBridgeAdapter decentBridgeAdapter,
            StargateBridgeAdapter stargateBridgeAdapter
        ) = deployUtb(
            decentEthRouter,
            decentBridgeExecutor
        );

        deployment = Deployment({
            decentBridgeExecutor: decentBridgeExecutor,
            decentEthRouter: decentEthRouter,
            dcntEth: dcntEth,
            utb: utb,
            utbExecutor: utbExecutor,
            utbFeeManager: utbFeeManager,
            uniSwapper: uniSwapper,
            decentBridgeAdapter: decentBridgeAdapter,
            stargateBridgeAdapter: stargateBridgeAdapter
        });
    }

    function connect() internal {
        connectBridge(
            TEST.SRC.dcntEth,
            TEST.DST.dcntEth,
            TEST.SRC.decentEthRouter,
            TEST.DST.decentEthRouter,
            TEST.CONFIG.dstLzId
        );
        connectBridge(
            TEST.DST.dcntEth,
            TEST.SRC.dcntEth,
            TEST.DST.decentEthRouter,
            TEST.SRC.decentEthRouter,
            TEST.CONFIG.srcLzId
        );
        connectUtb(
            TEST.SRC.decentBridgeAdapter,
            TEST.DST.decentBridgeAdapter,
            TEST.SRC.stargateBridgeAdapter,
            TEST.DST.stargateBridgeAdapter,
            TEST.CONFIG.dstChainId,
            TEST.CONFIG.dstLzId
        );
        connectUtb(
            TEST.DST.decentBridgeAdapter,
            TEST.SRC.decentBridgeAdapter,
            TEST.DST.stargateBridgeAdapter,
            TEST.SRC.stargateBridgeAdapter,
            TEST.CONFIG.srcChainId,
            TEST.CONFIG.srcLzId
        );
    }

    function liquify() public {
        addLiquidity(TEST.SRC.decentEthRouter, 10 ether);
        addLiquidity(TEST.DST.decentEthRouter, 10 ether);
    }

    function deployBridge(
        LZEndpointMock lzEndpoint
    ) internal returns (
        DecentBridgeExecutor decentBridgeExecutor,
        DecentEthRouter decentEthRouter,
        DcntEth dcntEth
    ) {
        decentBridgeExecutor = new DecentBridgeExecutor(TEST.CONFIG.weth, TEST.CONFIG.isGasEth);
        decentEthRouter = new DecentEthRouter(payable(TEST.CONFIG.weth), TEST.CONFIG.isGasEth, address(decentBridgeExecutor));
        decentBridgeExecutor.setOperator(address(decentEthRouter));

        dcntEth = new DcntEth(address(lzEndpoint));
        dcntEth.setRouter(address(decentEthRouter));
        decentEthRouter.registerDcntEth(address(dcntEth));
    }

    function deployUtb(
        DecentEthRouter decentEthRouter,
        DecentBridgeExecutor decentBridgeExecutor
    ) internal returns (
        UTB utb,
        UTBExecutor utbExecutor,
        UTBFeeManager utbFeeManager,
        UniSwapper uniSwapper,
        DecentBridgeAdapter decentBridgeAdapter,
        StargateBridgeAdapter stargateBridgeAdapter
    ) {
        utb = new UTB();
        utb.setWrapped(payable(TEST.CONFIG.weth));

        utbExecutor = deployUtbExecutor(utb);
        utbFeeManager = deployUtbFeeManager(utb);
        uniSwapper = deployUniSwapper(utb);
        decentBridgeAdapter = deployDecentBridgeAdapter(utb, decentEthRouter, decentBridgeExecutor);
        stargateBridgeAdapter = deployStargateBridgeAdapter(utb);
    }

    function deployUtbExecutor(UTB utb) internal returns (UTBExecutor utbExecutor) {
        utbExecutor = new UTBExecutor();
        utbExecutor.setOperator(address(utb));
        utb.setExecutor(address(utbExecutor));
    }

    function deployUtbFeeManager(UTB utb) internal returns (UTBFeeManager utbFeeManager) {
        utbFeeManager = new UTBFeeManager();
        utbFeeManager.setSigner(TEST.EOA.feeSigner);
        utb.setFeeManager(payable(address(utbFeeManager)));
    }

    function deployUniSwapper(UTB utb) internal returns (UniSwapper uniSwapper) {
        uniSwapper = new UniSwapper();
        uniSwapper.setWrapped(payable(TEST.CONFIG.weth));
        uniSwapper.setRouter(TEST.CONFIG.uniswap);
        uniSwapper.setUtb(address(utb));
        utb.registerSwapper(address(uniSwapper));
    }

    function deployDecentBridgeAdapter(
        UTB utb,
        DecentEthRouter decentEthRouter,
        DecentBridgeExecutor decentBridgeExecutor
    ) internal returns (
        DecentBridgeAdapter decentBridgeAdapter
    ) {
        address bridgeToken = TEST.CONFIG.isGasEth ? address(0) : TEST.CONFIG.weth;

        decentBridgeAdapter = new DecentBridgeAdapter(TEST.CONFIG.isGasEth, bridgeToken);
        decentBridgeAdapter.setUtb(address(utb));
        decentBridgeAdapter.setRouter(address(decentEthRouter));
        decentBridgeAdapter.setBridgeExecutor(address(decentBridgeExecutor));
        utb.registerBridge(address(decentBridgeAdapter));
    }

    function deployStargateBridgeAdapter(
        UTB utb
    ) internal returns (
        StargateBridgeAdapter stargateBridgeAdapter
    ) {
        stargateBridgeAdapter = new StargateBridgeAdapter();
        stargateBridgeAdapter.setUtb(address(utb));
        stargateBridgeAdapter.setRouter(TEST.CONFIG.stargateComposer);
        stargateBridgeAdapter.setBridgeExecutor(TEST.CONFIG.stargateComposer);
        utb.registerBridge(address(stargateBridgeAdapter));
    }

    function connectBridge(
        DcntEth srcDcntEth,
        DcntEth dstDcntEth,
        DecentEthRouter srcDecentEthRouter,
        DecentEthRouter dstDecentEthRouter,
        uint16 _dstLzId
    ) internal {
        uint256 minDstGas = 100_000;
        srcDecentEthRouter.addDestinationBridge(_dstLzId, address(dstDecentEthRouter));
        srcDcntEth.setTrustedRemote(_dstLzId, abi.encodePacked(dstDcntEth, srcDcntEth));
        srcDcntEth.setMinDstGas(
            _dstLzId,
            srcDcntEth.PT_SEND_AND_CALL(),
            minDstGas
        );
    }

    function connectUtb(
        DecentBridgeAdapter srcDecentBridgeAdapter,
        DecentBridgeAdapter dstDecentBridgeAdapter,
        StargateBridgeAdapter srcStargateBridgeAdapter,
        StargateBridgeAdapter dstStargateBridgeAdapter,
        uint256 _dstChainId,
        uint16 _dstLzId
    ) internal {
        srcDecentBridgeAdapter.registerRemoteBridgeAdapter(_dstChainId, _dstLzId, address(dstDecentBridgeAdapter));
        srcStargateBridgeAdapter.registerRemoteBridgeAdapter(_dstChainId, _dstLzId, address(dstStargateBridgeAdapter));
    }

    function addLiquidity(
        DecentEthRouter decentEthRouter,
        uint256 amount
    ) public {
        if (TEST.CONFIG.isGasEth) {
            decentEthRouter.addLiquidityEth{value: amount}();
        } else {
            WETH(payable(TEST.CONFIG.weth)).approve(address(decentEthRouter), amount);
            decentEthRouter.addLiquidityWeth(amount);
        }
    }

    function getSignature(
        bytes memory inputBytes
    ) public returns (bytes memory signature) {
        string memory BANNER = "\x19Ethereum Signed Message:\n32";

        bytes32 hash = keccak256(abi.encodePacked(BANNER, keccak256(inputBytes)));

        (/*address addr*/, uint256 privateKey) = makeAddrAndKey("FEE_SIGNER");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);

        signature = abi.encodePacked(r, s, v);
    }
}
