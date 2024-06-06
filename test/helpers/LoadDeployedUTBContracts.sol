// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {UTBExecutor} from "../../src/UTBExecutor.sol";
import {UTBFeeManager} from "../../src/UTBFeeManager.sol";
import {UTB, ISwapper} from "../../src/UTB.sol";
import {UTBDeployHelper} from "./UTBDeployHelper.sol";
import {DecentBridgeAdapter} from "../../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../../src/bridge_adapters/StargateBridgeAdapter.sol";
import {LoadDecentBridgeDeployedContracts} from "decent-bridge/script/util/LoadDecentBridgeDeployedContracts.sol";

contract LoadDeployedUTBContracts is
    UTBDeployHelper,
    LoadDecentBridgeDeployedContracts
{
    function loadDeployedUTBContracts(string memory chain) public {
        utbLookup[chain] = UTB(payable(getDeployment(chain, "UTB")));
        decentBridgeAdapterLookup[chain] = DecentBridgeAdapter(
            payable(getDeployment(chain, "DecentBridgeAdapter"))
        );
        sgBridgeAdapterLookup[chain] = StargateBridgeAdapter(
            payable(getDeployment(chain, "StargateBridgeAdapter"))
        );
        swapperLookup[chain] = ISwapper(
            payable(getDeployment(chain, "UniSwapper"))
        );
        feeManagerLookup[chain] = UTBFeeManager(
            payable(getDeployment(chain, "UTBFeeManager"))
        );
        // decent bridge info
        loadDecentBridgeContractsForChain(chain);
    }
}
