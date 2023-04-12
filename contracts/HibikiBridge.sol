// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol';
import { Auth } from "./Auth.sol";

contract HibikiBridge is AxelarExecutable, Auth {

	using StringToAddress for string;
	using AddressToString for address;

	IAxelarGasService public immutable gasService;
	IERC20 public hibiki;
	uint256 private _minFee = 1 ether;
	uint128 private _feeNumerator = 1;
	uint128 private _feeDenominator = 1000;
	uint256 private _bridgeLimit = 50000 ether;
	mapping (string => bool) _supportedChain;
	mapping (address => bool) _bridger;
	mapping (address => uint256) _pending;

	event BridgeRequest(address indexed bridgoor, address indexed receiver, uint256 amount, uint256 toReceive);
	event TokensBridged(address indexed receiver, uint256 amount);
	event TokensPending(address indexed receiver, uint256 amount);
	event PendingTokensClaimed(address indexed receiver, uint256 amount);

	error UnsupportedChain(string invalidChainId);
	error GasUnpaid();
	error InvalidSourceAddress(address source);
	error AmountOverLimit(uint256 amount, uint256 currentLimit);
	error ZeroAmount();
	error FeeOverLimit();

	modifier supportedChain(string calldata chain) {
		if (!_supportedChain[chain]) {
			revert UnsupportedChain(chain);
		}
		_;
	}

	modifier validSourceAddress(string calldata sourceAddress) {
		address from = sourceAddress.toAddress();
		if (!_bridger[from]) {
			revert InvalidSourceAddress(from);
		}
		_;
	}

	constructor(address gateway_, address gasReceiver_, address token) AxelarExecutable(gateway_) Auth(tx.origin) {
		gasService = IAxelarGasService(gasReceiver_);
		hibiki = IERC20(token);
		_supportedChain["Ethereum"] = true;
		_supportedChain["binance"] = true;
		_bridger[address(this)] = true;
	}

	function bridge(
		string calldata destinationChain,
		string calldata destinationAddress,
		address receiver,
		uint256 amount
	) external payable supportedChain(destinationChain) {
		// Always need gas paid to fund the bridge transaction.
		if (msg.value == 0) {
			revert GasUnpaid();
		}

		// Limit to how much you can bridge at once.
		uint256 currentLimit = _bridgeLimit;
		if (amount > currentLimit) {
			revert AmountOverLimit(amount, currentLimit);
		}

		// Cannot request bridge for 0 tokens.
		if (amount == 0) {
			revert ZeroAmount();
		}

		// Calculate amount to receive after fee.
		// This slowly generates bridge liquidity on both sides.
		uint256 toReceive = _getAmountAfterFee(amount);

		// Pay the gas to the service for the contract call.
		bytes memory payload = abi.encode(receiver, toReceive);
		gasService.payNativeGasForContractCall{value: msg.value} (
			address(this),
			destinationChain,
			destinationAddress,
			payload,
			msg.sender
		);

		// Send call to be done.
		gateway.callContract(destinationChain, destinationAddress, payload);

		// Finally, the tokens are transferred from owner to the bridge contract.
		hibiki.transferFrom(msg.sender, address(this), amount);
		emit BridgeRequest(msg.sender, receiver, amount, toReceive);
	}

	function _getAmountAfterFee(uint256 amount) private view returns (uint256) {
		uint256 minFee = _minFee;
		uint256 feeNumerator = _feeNumerator;

		// Check if there are no active fees.
		if (minFee == 0 && feeNumerator == 0) {
			return amount;
		}

		// Amount must be more than the minimim fee.
		if (amount <= minFee) {
			revert ZeroAmount();
		}

		// Calculate fee either from percentage or minimum fee.
		uint256 toReceive = amount;
		uint256 fee = amount * feeNumerator / _feeDenominator;
		if (fee < minFee) {
			fee = minFee;
		}

		// Amount must always be more than minfee, or we revert earlier.
		// If fee is higher than minfee, it's also always less than amount.
		unchecked {
			toReceive = amount - fee;
		}

		return toReceive;
	}

	function _execute(
		string calldata sourceChain,
		string calldata sourceAddress,
		bytes calldata payload
	) internal override supportedChain(sourceChain) validSourceAddress(sourceAddress) {
		(address receiver, uint256 amount) = abi.decode(payload, (address, uint256));
		uint256 bridgeBalance = hibiki.balanceOf(address(this));
		if (bridgeBalance > amount) {
			hibiki.transfer(receiver, amount);
			emit TokensBridged(receiver, amount);
		} else {
			// Bridge is empty. Store that the account is owed tokens.
			unchecked {
				_pending[receiver] += amount;
			}
			emit TokensPending(receiver, amount);
		}
	}

	/**
	 * @dev Check if account has any pending bridged tokens.
	 */
	function getPending(address bridgoor) external view returns (uint256) {
		return _pending[bridgoor];
	}

	/**
	 * @dev Request pending tokens to be bridged.
	 */
	function requestPending(address bridgoor) external {
		uint256 pending = _pending[bridgoor];
		if (pending > 0 && hibiki.balanceOf(address(this)) > pending) {
			delete _pending[bridgoor];
			hibiki.transfer(bridgoor, pending);
			emit PendingTokensClaimed(bridgoor, pending);
		}
	}

	function getCurrentFee() external view returns (uint256 numerator, uint256 denominator, uint256 min) {
		numerator = _feeNumerator;
		denominator = _feeDenominator;
		min = _minFee;
	}

	function getCurrentLimit() external view returns (uint256 limit) {
		limit = _bridgeLimit;
	}

	function recoverToken(address token) external authorized {
		IERC20 t = IERC20(token);
		t.transfer(msg.sender, t.balanceOf(address(this)));
	}

	function setMinFee(uint256 fee) external authorized {
		// The higher the min fee can be is 100 tokens.
		if (fee > 100 ether) {
			revert FeeOverLimit();
		}
		_minFee = fee;
	}

	function setFeeConfig(uint128 numerator, uint128 denominator) external authorized {
		// Max settable fee is 10%.
		// This is merely for security in case authorized address is compromised.
		// The only situation in which bridge fee should be over 0.1%-1% is
		// if this side of the bridge is almost empty.
		if (numerator > denominator / 10) {
			revert FeeOverLimit();
		}
		_feeNumerator = numerator;
		_feeDenominator = denominator;
	}

	function setIsChainSupported(string calldata chain, bool supported) external authorized {
		_supportedChain[chain] = supported;
	}

	function setCanBridge(address executor, bool allowed) external authorized {
		_bridger[executor] = allowed;
	}

	function setBridgeLimit(uint256 limit) external authorized {
		_bridgeLimit = limit;
	}
}
