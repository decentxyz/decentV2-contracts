// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge contracts
import "forge-std/Script.sol";
import "forge-std/console2.sol";

// bridge contracts
import {DcntEth} from "../lib/decent-bridge/src/DcntEth.sol";

// helper contracts
import {Tasks} from "./Scripts.sol";

interface IEndpoint {
    function libraryLookup(uint16) external returns (address);
    function getSendVersion(address) external returns (uint16);
    function getReceiveVersion(address) external returns (uint16);
}

contract UpgradeLzSetup is Script, Tasks {
    uint16 MAX_LOOKUP_ITERATIONS = 25;

    struct LzLibraries {
        address send301;
        address send302;
        address receive301;
        address receive302;
    }

    mapping(string => LzLibraries) lzLibraries;

    constructor() {
        lzLibraries[ethereum] = LzLibraries({
            send301: 0xD231084BfB234C107D3eE2b22F97F3346fDAF705,
            send302: 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1,
            receive301: 0x245B6e8FFE9ea5Fc301e32d16F66bD4C2123eEfC,
            receive302: 0xc02Ab410f0734EFa3F14628780e6e695156024C2
        });
        lzLibraries[sepolia] = LzLibraries({
            send301: 0x6862b19f6e42a810946B9C782E6ebE26Ad266C84,
            send302: 0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE,
            receive301: 0x5937A5fe272fbA38699A1b75B3439389EEFDb399,
            receive302: 0xdAf00F5eE2158dD58E0d3857851c432E34A3A851
        });
        lzLibraries[arbitrum] = LzLibraries({
            send301: 0x5cDc927876031B4Ef910735225c425A7Fc8efed9,
            send302: 0x975bcD720be66659e3EB3C0e4F1866a3020E493A,
            receive301: 0xe4DD168822767C4342e54e6241f0b91DE0d3c241,
            receive302: 0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6
        });
        lzLibraries[arbitrum_sepolia] = LzLibraries({
            send301: 0x92709d5BAc33547482e4BB7dd736f9a82b029c40,
            send302: 0x4f7cd4DA19ABB31b0eC98b9066B9e857B1bf9C0E,
            receive301: 0xa673a180fB2BF0E315b4f832b7d5b9ACB7162273,
            receive302: 0x75Db67CDab2824970131D5aa9CECfC9F69c69636
        });
        lzLibraries[optimism] = LzLibraries({
            send301: 0x3823094993190Fbb3bFABfEC8365b8C18517566F,
            send302: 0x1322871e4ab09Bc7f5717189434f97bBD9546e95,
            receive301: 0x6C9AE31DFB56699d6bD553146f653DCEC3b174Fe,
            receive302: 0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063
        });
        lzLibraries[optimism_sepolia] = LzLibraries({
            send301: 0xFe9335A931e2262009a73842001a6F91ef7B6778,
            send302: 0xB31D2cb502E25B30C651842C7C3293c51Fe6d16f,
            receive301: 0x420667429538adBF982aDa16C268ba561f097F74,
            receive302: 0x9284fd59B95b9143AF0b9795CAC16eb3C723C9Ca
        });
        lzLibraries[base] = LzLibraries({
            send301: 0x9DB3714048B5499Ec65F807787897D3b3Aa70072,
            send302: 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2,
            receive301: 0x58D53a2d6a08B72a15137F3381d21b90638bd753,
            receive302: 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf
        });
        lzLibraries[base_sepolia] = LzLibraries({
            send301: 0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648,
            send302: 0xC1868e054425D378095A003EcbA3823a5D0135C9,
            receive301: 0x9eCf72299027e8AeFee5DC5351D6d92294F46d2b,
            receive302: 0x12523de19dc41c91F7d2093E0CFbB76b17012C8d
        });
        lzLibraries[zora] = LzLibraries({
            send301: 0x7004396C99D5690da76A7C59057C5f3A53e01704,
            send302: 0xeDf930Cd8095548f97b21ec4E2dE5455a7382f04,
            receive301: 0x5EB6b3Db915d29fc624b8a0e42AC029e36a1D86B,
            receive302: 0x57D9775eE8feC31F1B612a06266f599dA167d211
        });
        lzLibraries[zora_goerli] = LzLibraries({
            send301: 0xfC78F0f43B3b485A3C2853b32856A686d260E1aC,
            send302: 0x87FE14Af115F3b14F7d91Be426C0213a24AE9498,
            receive301: 0x98434eb1F04ab5dFbEAcbA6C978b78E72C6Df744,
            receive302: 0xE321800e1D8277d2bf36A0979cd281c2B6760313
        });
        lzLibraries[zora_sepolia] = LzLibraries({
            send301: 0xcF1B0F4106B0324F96fEfcC31bA9498caa80701C,
            send302: 0xF49d162484290EAeAd7bb8C2c7E3a6f8f52e32d6,
            receive301: 0x00C5C0B8e0f75aB862CbAaeCfff499dB555FBDD2,
            receive302: 0xC1868e054425D378095A003EcbA3823a5D0135C9
        });
        lzLibraries[polygon] = LzLibraries({
            send301: 0x5727E81A40015961145330D91cC27b5E189fF3e1,
            send302: 0x6c26c61a97006888ea9E4FA36584c7df57Cd9dA3,
            receive301: 0x3823094993190Fbb3bFABfEC8365b8C18517566F,
            receive302: 0x1322871e4ab09Bc7f5717189434f97bBD9546e95
        });
        lzLibraries[polygon_mumbai] = LzLibraries({
            send301: 0x927587Ea40D0539Dd4beCD0e18E8EF47791D31Ab,
            send302: 0x5d9F8BCf9e07BabF517f2988986FF3bB7b233bc1,
            receive301: 0xaa5c6aF22CFC46DB8ba2c1A1c5ea6131b10ff575,
            receive302: 0xfa4Fbda8E809150eE1676ce675AC746Beb9aF379
        });
        lzLibraries[avalanche] = LzLibraries({
            send301: 0x31CAe3B7fB82d847621859fb1585353c5720660D,
            send302: 0x197D1333DEA5Fe0D6600E9b396c7f1B1cFCc558a,
            receive301: 0xF85eD5489E6aDd01Fec9e8D53cF8FAcFc70590BD,
            receive302: 0xbf3521d309642FA9B1c91A08609505BA09752c61
        });
        lzLibraries[avalanche_fuji] = LzLibraries({
            send301: 0x184e24e31657Cf853602589fe5304b144a826c85,
            send302: 0x69BF5f48d2072DfeBc670A1D19dff91D0F4E8170,
            receive301: 0x91df17bF1Ced54c6169e1E24722C0a88a447cBAf,
            receive302: 0x819F0FAF2cb1Fba15b9cB24c9A2BDaDb0f895daf
        });
        lzLibraries[fantom] = LzLibraries({
            send301: 0xeDD674b123662D1922d7060c10548ae58D4838af,
            send302: 0xC17BaBeF02a937093363220b0FB57De04A535D5E,
            receive301: 0xA374A435f3068FDf51dBd03b931D03AA6F878DA0,
            receive302: 0xe1Dd69A2D08dF4eA6a30a91cC061ac70F98aAbe3
        });
        lzLibraries[fantom_testnet] = LzLibraries({
            send301: 0x88bC8e61C33F8E3CCaBe7F3aD75e397c9E3732D0,
            send302: 0x3f41017De79aA979b8f33E2e9518203888458273,
            receive301: 0xE8ad92998674b08eaee83a720D47F442c51F86F3,
            receive302: 0xe4a446690Dfaf438EEA2b06394E1fdd0A9435178
        });
        lzLibraries[moonbeam] = LzLibraries({
            send301: 0xa62ACEff16b515e5B37e3D3bccE5a6fF8178aA84,
            send302: 0xeac136456d078bB76f59DCcb2d5E008b31AfE1cF,
            receive301: 0xeb2C36446b9A08634BaA970AEBf8888762d24beF,
            receive302: 0x2F4C6eeA955e95e6d65E08620D980C0e0e92211F
        });
        lzLibraries[moonbeam_testnet] = LzLibraries({
            send301: 0x7155A274c055a9D74C83f8cA13660781643062D4,
            send302: 0x4CC50568EdC84101097E06bCf736918f637e6aB7,
            receive301: 0xC192220C8bb485b46132EA9b17Eb5B2A552E2324,
            receive302: 0x5468b60ed00F9b389B5Ba660189862Db058D7dC8
        });
        lzLibraries[rarible] = LzLibraries({
            send301: 0xD4a903930f2c9085586cda0b11D9681EECb20D2f,
            send302: 0xA09dB5142654e3eB5Cf547D66833FAe7097B21C3,
            receive301: 0xb21f945e8917c6Cd69FcFE66ac6703B90f7fe004,
            receive302: 0x148f693af10ddfaE81cDdb36F4c93B31A90076e1
        });
        lzLibraries[rarible_testnet] = LzLibraries({
            send301: 0xC08DFdD85E8530420694dA94E34f52C7462cCe7d,
            send302: 0x7C424244B51d03cEEc115647ccE151baF112a42e,
            receive301: 0x7983dCA4B0E322b0B80AFBb01F1F904A0532FcB6,
            receive302: 0xbf06c8886E6904a95dD42440Bd237C4ac64940C8
        });
    }

    function getCurrentVersions(IEndpoint lzEndpoint, address lzApp) internal returns (
        uint16 sendVersion,
        uint16 receiveVersion
    ) {
        sendVersion = lzEndpoint.getSendVersion(lzApp);
        receiveVersion = lzEndpoint.getReceiveVersion(lzApp);
    }

    function getNewVersions(IEndpoint lzEndpoint, string memory chain) internal returns (
        uint16 sendVersion,
        uint16 receiveVersion
    ) {
        for (uint16 i; i < MAX_LOOKUP_ITERATIONS; i++) {
            address lib = lzEndpoint.libraryLookup(i);
            if (lib == lzLibraries[chain].send301) sendVersion = i;
            if (lib == lzLibraries[chain].receive301) receiveVersion = i;
            if ( sendVersion != 0 && receiveVersion != 0 ) break;
        }
    }
}

contract UpgradeLz is UpgradeLzSetup {

    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        DcntEth dcntEth = DcntEth(getDeployment(chain, "DcntEth"));
        IEndpoint lzEndpoint = IEndpoint(address(lzEndpointLookup[chain]));

        (uint16 currentSendVersion, uint16 currentReceiveVersion) = getCurrentVersions(lzEndpoint, address(dcntEth));
        (uint16 newSendVersion, uint16 newReceiveVersion) = getNewVersions(lzEndpoint, chain);

        require(newSendVersion != 0 && newReceiveVersion != 0, 'versions not found');
        require(newSendVersion != currentSendVersion || newReceiveVersion != currentReceiveVersion, 'upgrade already complete');

        console.log('currentSendVersion', currentSendVersion);
        console.log('currentReceiveVersion', currentReceiveVersion);
        console.log('newSendVersion', newSendVersion);
        console.log('newReceiveVersion', newReceiveVersion);

        vm.startBroadcast(account);

        dcntEth.setSendVersion(newSendVersion);
        dcntEth.setReceiveVersion(newReceiveVersion);

        vm.stopBroadcast();
    }
}


contract ConfirmVersions is UpgradeLzSetup {

    function run() external {
        string memory chain = vm.envString("CHAIN");

        DcntEth dcntEth = DcntEth(getDeployment(chain, "DcntEth"));
        IEndpoint lzEndpoint = IEndpoint(address(lzEndpointLookup[chain]));

        (uint16 currentSendVersion, uint16 currentReceiveVersion) = getCurrentVersions(lzEndpoint, address(dcntEth));
        (uint16 newSendVersion, uint16 newReceiveVersion) = getNewVersions(lzEndpoint, chain);

        console.log('currentSendVersion', currentSendVersion);
        console.log('currentReceiveVersion', currentReceiveVersion);
        console.log('newSendVersion', newSendVersion);
        console.log('newReceiveVersion', newReceiveVersion);

        assert(currentSendVersion == newSendVersion);
        assert(currentReceiveVersion == newReceiveVersion);
    }
}
