// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract ArbitrumFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("arbitrum"),
            srcChainId: 42161,
            dstChainId: 1,
            srcLzId: 110,
            dstLzId: 101,
            isGasEth: true,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            uniswap: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            stargateComposer: 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9,
            stargateEth: 0x915A55e36A01285A14f05dE6e81ED9cE89772f8e
        });

        initialize();
    }
}
