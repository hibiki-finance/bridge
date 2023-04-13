// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import { HibikiBridge } from "../src/HibikiBridge.sol";

contract Deploy is Script {

	function setUp() public {}

	function run() public {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		vm.startBroadcast(deployerPrivateKey);

		(address gateway, address gasService) = _getAxelarConfig();
		new HibikiBridge(gateway, gasService, _getHibikiAddress());

		vm.stopBroadcast();
	}

	function _getHibikiAddress() internal view returns (address) {
		if (block.chainid == 56) {
			return 0xA532cfaA916c465A094DAF29fEa07a13e41E5B36;
		}
		if (block.chainid == 97) {
			return 0xeC12d79597967aeBAf9b1bE75A8D51D29424DE15;
		}
		if (block.chainid == 1287) {
			return 0x89FaCEBDC11a879ed2096889621DB9f4D2ED5473;
		}

		return 0xA693032e8cfDB8115c6E72B60Ae77a1A592fe4bD;
	}

	function _getAxelarConfig() internal view returns (address, address) {
		if (block.chainid == 56) {
			return (0x304acf330bbE08d1e512eefaa92F6a57871fD895, 0x2d5d7d31F671F86C782533cc367F14109a082712);
		}
		if (block.chainid == 97) {
			return (0x4D147dCb984e6affEEC47e44293DA442580A3Ec0, 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6);
		}
		if (block.chainid == 1287) {
			return (0x5769D84DD62a6fD969856c75c7D321b84d455929, 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6);
		}

		return (0x4F4495243837681061C4743b74B3eEdf548D56A5, 0x2d5d7d31F671F86C782533cc367F14109a082712);
	}
}
