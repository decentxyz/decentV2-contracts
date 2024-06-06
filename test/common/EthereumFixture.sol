// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract EthereumFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("ethereum"),
            srcChainId: 1,
            dstChainId: 42161,
            srcLzId: 101,
            dstLzId: 110,
            isGasEth: true,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            uniswap: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            stargateComposer: 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9,
            stargateEth: 0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56
        });

        initialize();
    }
}
