// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import { HibikiBridge } from "../src/HibikiBridge.sol";
import "./mock/TestERC20.sol";
import "./mock/MockAxelarGateway.sol";
import "./mock/MockAxelarGasService.sol";
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol';

contract BridgeTest is Test {

	using StringToAddress for string;
	using AddressToString for address;

	TestERC20 private token;
	MockAxelarGateway private gateway;
	MockAxelarGasService private gasService;
	HibikiBridge private bridge;
	string private constant activeChain = "binance";

	event BridgeRequest(address indexed bridgoor, address indexed receiver, uint256 amount, uint256 toReceive);
	event TokensBridged(address indexed receiver, uint256 amount);
	event TokensPending(address indexed receiver, uint256 amount);
	event PendingTokensClaimed(address indexed receiver, uint256 amount);
	event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
		token = new TestERC20();
		gateway = new MockAxelarGateway();
		gasService = new MockAxelarGasService();
        bridge = new HibikiBridge(address(gateway), address(gasService), address(token));
		token.approve(address(bridge), type(uint256).max);
    }

	function test_TokenAddressAfterDeploy() public {
		assertEq(address(bridge.hibiki()), address(token));
	}

	function test_RevertWhen_GasNotSent() public {
		vm.expectRevert(HibikiBridge.GasUnpaid.selector);
		bridge.bridge(activeChain, address(bridge).toString(), address(this), 1 ether);
	}

	function test_RevertWhen_AmountZero() public {
		vm.expectRevert(HibikiBridge.ZeroAmount.selector);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), 0);
	}

	function test_RevertWhen_AmountEqualOrLessThanMinFee() public {
		(,,uint256 minFee) = bridge.getCurrentFee();
		vm.expectRevert(HibikiBridge.ZeroAmount.selector);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), minFee);
	}

	function test_BridgedAmountAppliedFee() public {
		(uint256 numerator, uint256 denominator, uint256 minFee) = bridge.getCurrentFee();

		// Applying min fee.
		uint256 bridgeAmount = minFee + 1 ether;
		vm.expectEmit(true, true, true, true);
		emit BridgeRequest(address(this), address(this), bridgeAmount, bridgeAmount - 1 ether);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), bridgeAmount);

		// Applying percentual fee.
		bridgeAmount = minFee * 1000;
		uint256 perFee = bridgeAmount * numerator / denominator;
		vm.expectEmit(true, true, true, true);
		emit BridgeRequest(address(this), address(this), bridgeAmount, bridgeAmount - perFee);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), bridgeAmount);
	}

	function test_BridgedTokensTransferred() public {
		uint256 balanceUserBefore = token.balanceOf(address(this));
		uint256 balanceBridgeBefore = token.balanceOf(address(bridge));
		(,,uint256 minFee) = bridge.getCurrentFee();
		uint256 bridgeAmount = minFee * 10;
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), bridgeAmount);
		assertEq(token.balanceOf(address(this)), balanceUserBefore - bridgeAmount);
		assertEq(token.balanceOf(address(bridge)), balanceBridgeBefore + bridgeAmount);
	}

	function test_RevertWhen_AmountOverLimit() public {
		uint256 limit = bridge.getCurrentLimit();
		uint256 amount = limit + 1 ether;
		vm.expectRevert(abi.encodeWithSelector(HibikiBridge.AmountOverLimit.selector, amount, limit));
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), amount);
	}

	function test_ExecuteSendsTokens() public {
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		token.transfer(address(bridge), bridgeAmount + 1);
		uint256 balanceUserBefore = token.balanceOf(receiver);
		uint256 balanceBridgeBefore = token.balanceOf(address(bridge));
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		vm.expectEmit(true, true, false, false);
		emit TokensBridged(receiver, bridgeAmount);
		bridge.execute(gateway.correctCommandId(), activeChain, address(bridge).toString(), payload);
		assertEq(token.balanceOf(receiver), balanceUserBefore + bridgeAmount);
		assertEq(token.balanceOf(address(bridge)), balanceBridgeBefore - bridgeAmount);
	}

	function test_RevertWhen_UnsupportedChain() public {
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		string memory wrong = "wrongchain";
		bytes32 commandId = gateway.correctCommandId();
		vm.expectRevert(abi.encodeWithSelector(HibikiBridge.UnsupportedChain.selector, wrong));
		bridge.execute(commandId, wrong, address(bridge).toString(), payload);
	}

	function test_RevertWhen_ExecuteFromDifferentAddress() public {
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		bytes32 commandId = gateway.correctCommandId();
		vm.expectRevert(abi.encodeWithSelector(HibikiBridge.InvalidSourceAddress.selector, address(0xdead)));
		bridge.execute(commandId, activeChain, address(0xdead).toString(), payload);
	}

	function test_MarkedAsPendingWhen_BridgeLacksLiquidity() public {
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		bytes32 commandId = gateway.correctCommandId();
		uint256 balanceUserBefore = token.balanceOf(receiver);
		vm.expectEmit(true, true, false, false);
		emit TokensPending(receiver, bridgeAmount);
		bridge.execute(commandId, activeChain, address(bridge).toString(), payload);
		assertEq(token.balanceOf(receiver), balanceUserBefore);
	}

	function test_BalanceUnchagedWhen_PendingRequestOnNoPending() public {
		address noPendoor = address(0xbeef);
		uint256 pending = bridge.getPending(noPendoor);
		assertEq(pending, 0);
		uint256 balanceUserBefore = token.balanceOf(noPendoor);
		bridge.requestPending(noPendoor);
		assertEq(token.balanceOf(noPendoor), balanceUserBefore);
	}

	function test_PendingRequestSendsTokens() public {
		address receiver = address(this);
		uint256 bridgeAmount = 100 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		bytes32 commandId = gateway.correctCommandId();
		bridge.execute(commandId, activeChain, address(bridge).toString(), payload);
		token.transfer(address(bridge), bridgeAmount + 1);
		uint256 balanceUserBefore = token.balanceOf(receiver);
		vm.expectEmit(true, true, false, false);
		emit PendingTokensClaimed(receiver, bridgeAmount);
		bridge.requestPending(receiver);
		assertEq(token.balanceOf(receiver), balanceUserBefore + bridgeAmount);
		uint256 pending = bridge.getPending(receiver);
		assertEq(pending, 0);
	}

	function test_RevertWhen_UnauthorizedRecoverToken() public {
		vm.prank(address(0xb33f));
		vm.expectRevert("!AUTHORIZED");
		bridge.recoverToken(address(token));
	}

	function test_RevertWhen_UnauthorizedSetMinFee() public {
		vm.prank(address(0xb33f));
		vm.expectRevert("!AUTHORIZED");
		bridge.setMinFee(1);
	}

	function test_RevertWhen_UnauthorizedSetFeeConfig() public {
		vm.prank(address(0xb33f));
		vm.expectRevert("!AUTHORIZED");
		bridge.setFeeConfig(1, 100);
	}

	function test_RevertWhen_UnauthorizedSetSupportedChain() public {
		vm.prank(address(0xb33f));
		vm.expectRevert("!AUTHORIZED");
		bridge.setIsChainSupported("chain", true);
	}

	function test_RevertWhen_UnauthorizeSetCanBridge() public {
		address unauth = address(0xb33f);
		vm.prank(unauth);
		vm.expectRevert("!AUTHORIZED");
		bridge.setCanBridge(unauth, true);
	}

	function test_RevertWhen_UnauthorizedSetBridgeLimit() public {
		vm.prank(address(0xb33f));
		vm.expectRevert("!AUTHORIZED");
		bridge.setBridgeLimit(9001 ether);
	}

	function test_RevertWhen_SetMinFeeTooHigh() public {
		vm.prank(tx.origin);
		vm.expectRevert(HibikiBridge.FeeOverLimit.selector);
		bridge.setMinFee(101 ether);
	}

	function test_RevertWhen_SetFeesTooHigh() public {
		vm.prank(tx.origin);
		vm.expectRevert(HibikiBridge.FeeOverLimit.selector);
		bridge.setFeeConfig(1, 9);
	}

	function test_MinFeeUpdated() public {
		(,,uint256 minFee) = bridge.getCurrentFee();
		uint256 newFee = minFee + 0.1 ether;
		vm.prank(tx.origin);
		bridge.setMinFee(newFee);
		(,,minFee) = bridge.getCurrentFee();
		assertEq(minFee, newFee);
	}

	function test_FeeConfigUpdated() public {
		(uint256 numerator, uint256 denominator,) = bridge.getCurrentFee();
		uint256 newDenominator = denominator + 1;
		vm.prank(tx.origin);
		bridge.setFeeConfig(uint128(numerator), uint128(newDenominator));
		(uint256 currentNumerator, uint256 currentDenominator,) = bridge.getCurrentFee();
		assertEq(currentNumerator, numerator);
		assertEq(currentDenominator, newDenominator);
	}

	function test_SetChainSupported() public {
		string memory toSupport = "newchain";
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		bytes32 commandId = gateway.correctCommandId();
		vm.expectRevert(abi.encodeWithSelector(HibikiBridge.UnsupportedChain.selector, toSupport));
		bridge.execute(commandId, toSupport, address(bridge).toString(), payload);
		vm.prank(tx.origin);
		bridge.setIsChainSupported(toSupport, true);
		bridge.execute(commandId, toSupport, address(bridge).toString(), payload);
	}

	function test_SetCanBridge() public {
		address newBridger = address(0x1337);
		address receiver = address(this);
		uint256 bridgeAmount = 10 ether;
		bytes memory payload = abi.encode(receiver, bridgeAmount);
		bytes32 commandId = gateway.correctCommandId();
		vm.expectRevert(abi.encodeWithSelector(HibikiBridge.InvalidSourceAddress.selector, newBridger));
		bridge.execute(commandId, activeChain, newBridger.toString(), payload);
		vm.prank(tx.origin);
		bridge.setCanBridge(newBridger, true);
		bridge.execute(commandId, activeChain, newBridger.toString(), payload);
	}

	function test_SetBridgeLimit() public {
		uint256 limit = bridge.getCurrentLimit();
		uint256 newLimit = limit * 2;
		vm.prank(tx.origin);
		bridge.setBridgeLimit(limit * 2);
		assertEq(bridge.getCurrentLimit(), newLimit);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), newLimit - 1);
	}

	function test_CanRecoverTokens() public {
		uint256 balanceBefore = token.balanceOf(address(bridge));
		uint256 toTransfer = 1000 ether;
		token.transfer(address(bridge), toTransfer);
		uint256 newBalance = token.balanceOf(address(bridge));
		assertEq(newBalance, balanceBefore + toTransfer);
		vm.expectEmit(true, true, true, false);
		emit Transfer(address(bridge), tx.origin, newBalance);
		vm.prank(tx.origin);
		bridge.recoverToken(address(token));
		assertEq(token.balanceOf(address(bridge)), 0);
	}

	function test_BridgedAmountEqualWhen_FeesSetToZero() public {
		vm.prank(tx.origin);
		bridge.setMinFee(0);
		vm.prank(tx.origin);
		bridge.setFeeConfig(0, 0);

		uint256 bridgeAmount = 100 ether;
		vm.expectEmit(true, true, true, true);
		emit BridgeRequest(address(this), address(this), bridgeAmount, bridgeAmount);
		bridge.bridge{value: 0.1 ether}(activeChain, address(bridge).toString(), address(this), bridgeAmount);
	}
}
