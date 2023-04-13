// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

contract MockAxelarGateway {

	bytes32 public immutable correctCommandId = "ProperBridgeRequest";
	mapping (bytes32 => bool) private _commandsValid;

	function validateContractCall(
		bytes32 commandId,
		string calldata/* sourceChain*/,
		string calldata/* sourceAddress*/,
		bytes32/* payloadHash*/
	) external returns (bool valid) {
		valid = commandId == correctCommandId;
		_commandsValid[commandId] = valid;
	}

	function callContract(
        string calldata/* destinationChain*/,
        string calldata/* contractAddress*/,
        bytes calldata/* payload*/
    ) external {}
}
