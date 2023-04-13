// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import { HibikiBridge } from "../src/HibikiBridge.sol";
import "./mock/TestERC20.sol";
import "./mock/MockAxelarGateway.sol";
import "./mock/MockAxelarGasService.sol";

contract AuthTest is Test {

	TestERC20 private token;
	MockAxelarGateway private gateway;
	MockAxelarGasService private gasService;
	HibikiBridge private bridge;

    function setUp() public {
		token = new TestERC20();
		gateway = new MockAxelarGateway();
		gasService = new MockAxelarGasService();
        bridge = new HibikiBridge(address(gateway), address(gasService), address(token));
    }

	function test_RevertWhen_AuthorizeByNonOwner() public {
		vm.expectRevert("!OWNER");
		bridge.authorize(address(0xbeef));
	}

	function test_AuthorizeUnauthorizeFlow() public {
		address newAuth = address(0xbeef);
		assertEq(bridge.isAuthorized(newAuth), false);
		vm.prank(tx.origin);
		bridge.authorize(newAuth);
		assertEq(bridge.isAuthorized(newAuth), true);
		vm.prank(tx.origin);
		bridge.unauthorize(newAuth);
		assertEq(bridge.isAuthorized(newAuth), false);
	}

	function test_RevertWhen_UnauthorizeByNonOwner() public {
		vm.expectRevert("!OWNER");
		bridge.unauthorize(address(0xbeef));
	}

	function test_IsOwner() public {
		assertEq(bridge.isOwner(tx.origin), true);
		assertEq(bridge.isOwner(address(0xbeef)), false);
	}

	function test_TransferOwnership() public {
		address payable newOwner = payable(address(0xbeef));
		assertEq(bridge.isOwner(newOwner), false);
		vm.prank(tx.origin);
		bridge.transferOwnership(newOwner);
		assertEq(bridge.isOwner(newOwner), true);
		assertEq(bridge.isAuthorized(tx.origin), true);
	}

	function Test_RevertWhen_TransferOwnershipByNonOwner() public {
		vm.expectRevert("!OWNER");
		bridge.transferOwnership(payable(address(0xbeef)));
	}
}
