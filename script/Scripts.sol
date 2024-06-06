// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge contracts
import "forge-std/Script.sol";
import "forge-std/console2.sol";

// bridge contracts
import {DecentBridgeExecutor} from "../lib/decent-bridge/src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "../lib/decent-bridge/src/DecentEthRouter.sol";
import {DcntEth} from "../lib/decent-bridge/src/DcntEth.sol";

// utb contracts
import {UTB} from "../src/UTB.sol";
import {UTBExecutor} from "../src/UTBExecutor.sol";
import {UTBFeeManager} from "../src/UTBFeeManager.sol";
import {UniSwapper} from "../src/swappers/UniSwapper.sol";
import {DecentBridgeAdapter} from "../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../src/bridge_adapters/StargateBridgeAdapter.sol";

// forge toolkit contract
import {LoadAllChainInfo} from "forge-toolkit/LoadAllChainInfo.sol";
import {UniswapRouterHelpers} from "forge-toolkit/UniswapRouterHelpers.sol";

// eip contracts
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Tasks is LoadAllChainInfo, UniswapRouterHelpers {
    string constant DEPLOY_FILE = "./deployments/addresses.json";
    uint256 constant SIGNER_PRIVATE_KEY = uint256(0xC0FFEE);
    uint constant MIN_DST_GAS = 100_000;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    uint16 public constant PT_SEND_AND_CALL = 1;

    constructor() {
        loadAllChainInfo();
        loadAllUniRouterInfo();
    }

    function logDeployment(string memory contractName, address contractAddress) internal {
        string memory chain = vm.envString("CHAIN");
        string memory json;
        json = vm.serializeAddress(json, contractName, contractAddress);
        vm.writeJson(json, DEPLOY_FILE, string.concat(".", chain));
    }

    function getDeployment(
        string memory chain,
        string memory contractName
    ) internal returns (address deployment) {
        string memory json = vm.readFile(DEPLOY_FILE);
        string memory path = string.concat(".", chain, ".", contractName);
        string memory label = string.concat(chain, "_", contractName);
        deployment = vm.parseJsonAddress(json, path);
        vm.label(deployment, label);
    }

    function deployBridge() internal returns (
        DecentBridgeExecutor decentBridgeExecutor,
        DecentEthRouter decentEthRouter,
        DcntEth dcntEth
    ) {
        string memory chain = vm.envString("CHAIN");
        address weth = wethLookup[chain];
        bool isGasEth = gasEthLookup[chain];
        address lzEndpoint = address(lzEndpointLookup[chain]);

        decentBridgeExecutor = new DecentBridgeExecutor(weth, isGasEth);
        decentEthRouter = new DecentEthRouter(payable(weth), isGasEth, address(decentBridgeExecutor));
        dcntEth = new DcntEth(lzEndpoint);
    }

    function configureBridge(
        address _dcntEth,
        address _decentEthRouter,
        address _decentBridgeExecutor
    ) internal {
        DcntEth dcntEth = DcntEth(_dcntEth);
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));
        DecentBridgeExecutor decentBridgeExecutor = DecentBridgeExecutor(payable(_decentBridgeExecutor));

        dcntEth.setRouter(_decentEthRouter);
        decentEthRouter.registerDcntEth(_dcntEth);
        decentBridgeExecutor.setOperator(_decentEthRouter);
    }

    function deployUtb() internal returns (
        UTB utb,
        UTBExecutor utbExecutor,
        UTBFeeManager utbFeeManager,
        UniSwapper uniSwapper,
        DecentBridgeAdapter decentBridgeAdapter,
        StargateBridgeAdapter stargateBridgeAdapter
    ) {
        string memory chain = vm.envString("CHAIN");
        bool gasIsEth = gasEthLookup[chain];
        address weth = wethLookup[chain];
        address bridgeToken = gasIsEth ? address(0) : weth;

        utb = new UTB();
        utbExecutor = new UTBExecutor();
        utbFeeManager = new UTBFeeManager();
        uniSwapper = new UniSwapper();
        decentBridgeAdapter = new DecentBridgeAdapter(gasIsEth, bridgeToken);
        stargateBridgeAdapter = new StargateBridgeAdapter();
    }

    function configureUtb(
        address utb,
        address utbExecutor,
        address utbFeeManager,
        address uniSwapper,
        address decentBridgeAdapter,
        address decentEthRouter,
        address decentBridgeExecutor,
        address stargateBridgeAdapter
    ) internal {
        string memory chain = vm.envString("CHAIN");
        address wrapped = wrappedLookup[chain];
        UTB(payable(utb)).setWrapped(payable(wrapped));

        configureUtbExecutor(utbExecutor, utb);
        configureUtbFeeManager(utbFeeManager, utb);
        configureUniSwapper(uniSwapper, utb);
        configureDecentBridgeAdapter(decentBridgeAdapter, utb, decentEthRouter, decentBridgeExecutor);
        configureStargateBridgeAdapter(stargateBridgeAdapter, utb);
    }

    function configureUtbExecutor(
        address utbExecutor,
        address utb
    ) internal {
        UTBExecutor(utbExecutor).setOperator(utb);
        UTB(payable(utb)).setExecutor(utbExecutor);
    }

    function configureUtbFeeManager(address utbFeeManager, address utb) internal {
        UTBFeeManager(utbFeeManager).setSigner(vm.addr(SIGNER_PRIVATE_KEY));
        UTB(payable(utb)).setFeeManager(payable(utbFeeManager));
    }

    function configureUniSwapper(address _uniSwapper, address utb) internal {
        string memory chain = vm.envString("CHAIN");
        address wrapped = wrappedLookup[chain];
        address uniRouter = uniRouterLookup[chain];

        UniSwapper uniSwapper = UniSwapper(payable(_uniSwapper));
        uniSwapper.setWrapped(payable(wrapped));
        uniSwapper.setRouter(uniRouter);
        uniSwapper.setUtb(utb);
        UTB(payable(utb)).registerSwapper(address(uniSwapper));
    }

    function configureDecentBridgeAdapter(
        address _decentBridgeAdapter,
        address utb,
        address decentEthRouter,
        address decentBridgeExecutor
    ) internal {
        DecentBridgeAdapter decentBridgeAdapter = DecentBridgeAdapter(payable(_decentBridgeAdapter));
        decentBridgeAdapter.setUtb(utb);
        decentBridgeAdapter.setRouter(decentEthRouter);
        decentBridgeAdapter.setBridgeExecutor(decentBridgeExecutor);
        UTB(payable(utb)).registerBridge(_decentBridgeAdapter);
    }

    function configureStargateBridgeAdapter(
        address _stargateBridgeAdapter,
        address utb
    ) internal {
        string memory chain = vm.envString("CHAIN");
        address stargateComposer = sgComposerLookup[chain];

        StargateBridgeAdapter stargateBridgeAdapter = StargateBridgeAdapter(payable(_stargateBridgeAdapter));
        stargateBridgeAdapter.setUtb(utb);
        stargateBridgeAdapter.setRouter(stargateComposer);
        stargateBridgeAdapter.setBridgeExecutor(stargateComposer);
        UTB(payable(utb)).registerBridge(_stargateBridgeAdapter);
    }

    function connectBridge(
        address _srcDcntEth,
        address dstDcntEth,
        address _srcDecentEthRouter,
        address dstDecentEthRouter,
        uint16 dstLzId
    ) internal {
        DcntEth srcDcntEth = DcntEth(_srcDcntEth);
        DecentEthRouter srcDecentEthRouter = DecentEthRouter(payable(_srcDecentEthRouter));

        srcDecentEthRouter.addDestinationBridge(dstLzId, dstDecentEthRouter);
        srcDcntEth.setTrustedRemote(dstLzId, abi.encodePacked(dstDcntEth, srcDcntEth));
        srcDcntEth.setMinDstGas(
            dstLzId,
            PT_SEND_AND_CALL,
            MIN_DST_GAS
        );
    }

    function connectUtb(
        address _srcDecentBridgeAdapter,
        address dstDecentBridgeAdapter,
        address _srcStargateBridgeAdapter,
        address dstStargateBridgeAdapter,
        uint256 dstChainId,
        uint16 dstLzId
    ) internal {
        DecentBridgeAdapter srcDecentBridgeAdapter = DecentBridgeAdapter(payable(_srcDecentBridgeAdapter));
        StargateBridgeAdapter srcStargateBridgeAdapter = StargateBridgeAdapter(payable(_srcStargateBridgeAdapter));

        srcDecentBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzId, dstDecentBridgeAdapter);
        srcStargateBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzId, dstStargateBridgeAdapter);
    }

    function addLiquidity(address _decentEthRouter, uint256 amount) public {
        string memory chain = vm.envString("CHAIN");
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        if (gasEthLookup[chain]) {
            decentEthRouter.addLiquidityEth{value: amount}();
        } else {
            ERC20(wethLookup[chain]).approve(address(decentEthRouter), amount);
            decentEthRouter.addLiquidityWeth(amount);
        }
    }

    function removeLiquidity(address _decentEthRouter, uint256 amount) public {
        string memory chain = vm.envString("CHAIN");
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        if (gasEthLookup[chain]) {
            decentEthRouter.removeLiquidityEth(amount);
        } else {
            decentEthRouter.removeLiquidityWeth(amount);
        }
    }

    function bridge(address _decentEthRouter, address to, uint256 amount, uint16 dstLzId) public {
        uint64 gas = 120e3;
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        (uint nativeFee, uint zroFee) = decentEthRouter.estimateSendAndCallFee(
            0,
            dstLzId,
            to,
            msg.sender,
            amount,
            gas,
            true,
            ""
        );

        decentEthRouter.bridge{value: nativeFee + zroFee + amount}(
            dstLzId,
            to,
            msg.sender,
            amount,
            gas,
            true
        );
    }

    function addAdminToBridge(
        address admin,
        address _decentBridgeExecutor,
        address _decentEthRouter,
        address _dcntEth
    ) public {
        DecentBridgeExecutor decentBridgeExecutor = DecentBridgeExecutor(payable(_decentBridgeExecutor));
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));
        DcntEth dcntEth = DcntEth(_dcntEth);

        decentBridgeExecutor.grantRole(DEFAULT_ADMIN_ROLE, admin);
        decentEthRouter.grantRole(DEFAULT_ADMIN_ROLE, admin);
        dcntEth.grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function addAdminToUtb(
        address admin,
        address _utb,
        address _utbExecutor,
        address _utbFeeManager,
        address _uniSwapper,
        address _decentBridgeAdapter,
        address _stargateBridgeAdapter
    ) public {
        UTB utb = UTB(payable(_utb));
        UTBExecutor utbExecutor = UTBExecutor(_utbExecutor);
        UTBFeeManager utbFeeManager = UTBFeeManager(_utbFeeManager);
        UniSwapper uniSwapper = UniSwapper(payable(_uniSwapper));
        DecentBridgeAdapter decentBridgeAdapter = DecentBridgeAdapter(payable(_decentBridgeAdapter));
        StargateBridgeAdapter stargateBridgeAdapter = StargateBridgeAdapter(payable(_stargateBridgeAdapter));

        utb.grantRole(DEFAULT_ADMIN_ROLE, admin);
        utbExecutor.grantRole(DEFAULT_ADMIN_ROLE, admin);
        utbFeeManager.grantRole(DEFAULT_ADMIN_ROLE, admin);
        uniSwapper.grantRole(DEFAULT_ADMIN_ROLE, admin);
        decentBridgeAdapter.grantRole(DEFAULT_ADMIN_ROLE, admin);
        stargateBridgeAdapter.grantRole(DEFAULT_ADMIN_ROLE, admin);
    }
}

contract Deploy is Script, Tasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        require(wethLookup[chain] != address(0), string.concat('no weth for chain: ', chain));
        require(address(lzEndpointLookup[chain]) != address(0), string.concat('no lz endpoint for chain: ', chain));

        vm.startBroadcast(account);

        (
            DecentBridgeExecutor decentBridgeExecutor,
            DecentEthRouter decentEthRouter,
            DcntEth dcntEth
        ) = deployBridge();

        (
            UTB utb,
            UTBExecutor utbExecutor,
            UTBFeeManager utbFeeManager,
            UniSwapper uniSwapper,
            DecentBridgeAdapter decentBridgeAdapter,
            StargateBridgeAdapter stargateBridgeAdapter
        ) = deployUtb();

        vm.stopBroadcast();

        logDeployment("DecentBridgeExecutor", address(decentBridgeExecutor));
        logDeployment("DecentEthRouter", address(decentEthRouter));
        logDeployment("DcntEth", address(dcntEth));
        logDeployment("UTB", address(utb));
        logDeployment("UTBExecutor", address(utbExecutor));
        logDeployment("UTBFeeManager", address(utbFeeManager));
        logDeployment("UniSwapper", address(uniSwapper));
        logDeployment("DecentBridgeAdapter", address(decentBridgeAdapter));
        logDeployment("StargateBridgeAdapter", address(stargateBridgeAdapter));
    }
}

contract Configure is Script, Tasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        require(wrappedLookup[chain] != address(0), string.concat('no wrapped for chain: ', chain));
        // require(uniRouterLookup[chain] != address(0), string.concat('no uniswap router for chain: ', chain));
        // require(sgComposerLookup[chain] != address(0), string.concat('no stargate composer for chain: ', chain));

        address dcntEth = getDeployment(chain, "DcntEth");
        address decentEthRouter = getDeployment(chain, "DecentEthRouter");
        address decentBridgeExecutor = getDeployment(chain, "DecentBridgeExecutor");
        address utb = getDeployment(chain, "UTB");
        address utbExecutor = getDeployment(chain, "UTBExecutor");
        address utbFeeManager = getDeployment(chain, "UTBFeeManager");
        address uniSwapper = getDeployment(chain, "UniSwapper");
        address decentBridgeAdapter = getDeployment(chain, "DecentBridgeAdapter");
        address stargateBridgeAdapter = getDeployment(chain, "StargateBridgeAdapter");

        vm.startBroadcast(account);

        configureBridge(
            dcntEth,
            decentEthRouter,
            decentBridgeExecutor
        );

        configureUtb(
            utb,
            utbExecutor,
            utbFeeManager,
            uniSwapper,
            decentBridgeAdapter,
            decentEthRouter,
            decentBridgeExecutor,
            stargateBridgeAdapter
        );

        vm.stopBroadcast();
    }
}

contract AddLiquidity is Script, Tasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        address decentEthRouter = getDeployment(chain, "DecentEthRouter");
        addLiquidity(decentEthRouter, amount);

        vm.stopBroadcast();
    }
}

contract RemoveLiquidity is Script, Tasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        address decentEthRouter = getDeployment(chain, "DecentEthRouter");
        removeLiquidity(decentEthRouter, amount);

        vm.stopBroadcast();
    }
}

contract Connect is Script, Tasks {
    function run() external {
        string memory src = vm.envString("SRC");
        string memory dst = vm.envString("DST");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address srcDcntEth = getDeployment(src, "DcntEth");
        address dstDcntEth = getDeployment(dst, "DcntEth");

        address srcDecentEthRouter = getDeployment(src, "DecentEthRouter");
        address dstDecentEthRouter = getDeployment(dst, "DecentEthRouter");

        address srcDecentBridgeAdapter = getDeployment(src, "DecentBridgeAdapter");
        address dstDecentBridgeAdapter = getDeployment(dst, "DecentBridgeAdapter");

        address srcStargateBridgeAdapter = getDeployment(src, "StargateBridgeAdapter");
        address dstStargateBridgeAdapter = getDeployment(dst, "StargateBridgeAdapter");

        uint16 dstLzId = lzIdLookup[dst];
        uint256 dstChainId = chainIdLookup[dst];

        require(dstLzId != 0, string.concat('no lz id for chain: ', dst));
        require(dstChainId != 0, string.concat('no chain id for chain: ', dst));

        vm.startBroadcast(account);

        connectBridge(
            srcDcntEth,
            dstDcntEth,
            srcDecentEthRouter,
            dstDecentEthRouter,
            dstLzId
        );

        connectUtb(
            srcDecentBridgeAdapter,
            dstDecentBridgeAdapter,
            srcStargateBridgeAdapter,
            dstStargateBridgeAdapter,
            dstChainId,
            dstLzId
        );

        vm.stopBroadcast();
    }
}

contract Bridge is Script, Tasks {
    function run() public {
        uint256 amount = vm.envUint("AMOUNT");
        string memory src = vm.envString("SRC");
        string memory dst = vm.envString("DST");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address decentEthRouter = getDeployment(src, "DecentEthRouter");
        address to = vm.addr(account);
        uint16 dstLzId = lzIdLookup[dst];

        require(dstLzId != 0, string.concat('no lz id for chain: ', dst));

        vm.startBroadcast(account);

        bridge(decentEthRouter, to, amount, dstLzId);

        vm.stopBroadcast();
    }
}

contract AddAdmin is Script, Tasks {
    function run() public {
        string memory chain = vm.envString("CHAIN");
        address admin = vm.envAddress("ADMIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address decentBridgeExecutor = getDeployment(chain, 'DecentBridgeExecutor');
        address decentEthRouter = getDeployment(chain, 'DecentEthRouter');
        address dcntEth = getDeployment(chain, 'DcntEth');
        address utb = getDeployment(chain, 'UTB');
        address utbExecutor = getDeployment(chain, 'UTBExecutor');
        address utbFeeManager = getDeployment(chain, 'UTBFeeManager');
        address uniSwapper = getDeployment(chain, 'UniSwapper');
        address decentBridgeAdapter = getDeployment(chain, 'DecentBridgeAdapter');
        address stargateBridgeAdapter = getDeployment(chain, 'StargateBridgeAdapter');

        vm.startBroadcast(account);

        addAdminToBridge(
            admin,
            decentBridgeExecutor,
            decentEthRouter,
            dcntEth
        );

        addAdminToUtb(
            admin,
            utb,
            utbExecutor,
            utbFeeManager,
            uniSwapper,
            decentBridgeAdapter,
            stargateBridgeAdapter
        );

        vm.stopBroadcast();
    }
}

contract SetUniSwapperRouter is Script, Tasks {
    function run() public {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address _uniSwapper = getDeployment(chain, 'UniSwapper');
        UniSwapper uniSwapper = UniSwapper(payable(_uniSwapper));
        address uniRouter = uniRouterLookup[chain];

        vm.startBroadcast(account);

        uniSwapper.setRouter(uniRouter);

        vm.stopBroadcast();
    }
}

contract LogConfig is Script, Tasks {
    function run() view public {
        string memory chain = vm.envString("CHAIN");

        console2.log(string.concat('CONFIG FOR CHAIN: ', chain));
        console2.log('gasEthLookup', gasEthLookup[chain]);
        console2.log('wethLookup', wethLookup[chain]);
        console2.log('lzEndpointLookup', address(lzEndpointLookup[chain]));
        console2.log('lzIdLookup', lzIdLookup[chain]);
        console2.log('chainIdLookup', chainIdLookup[chain]);
        console2.log('wrappedLookup', wrappedLookup[chain]);
        console2.log('uniRouterLookup', uniRouterLookup[chain]);
        console2.log('sgComposerLookup', sgComposerLookup[chain]);
        console2.log('decentBridgeToken', gasEthLookup[chain] ? address(0) : wethLookup[chain]);
    }
}

contract Simulate is Script, Tasks {
    function run() public {
        address from = vm.envAddress("FROM");
        address to = vm.envAddress("TO");
        uint value = vm.envUint("VALUE");
        bytes memory data = vm.envBytes("CALLDATA");

        vm.prank(from);
        (to.call{value: value}(data));
    }
}
