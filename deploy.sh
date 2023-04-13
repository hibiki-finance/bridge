#!/bin/bash
source .env

case $1 in
	bsctest)
		forge script script/01_Deploy.s.sol:Deploy --rpc-url $BSC_TESTNET_RPC --broadcast --chain-id 97
		;;
	bsc)
		forge script script/01_Deploy.s.sol:Deploy --rpc-url $BSC_RPC --broadcast --chain-id 56
		;;
	eth)
		forge script script/01_Deploy.s.sol:Deploy --rpc-url $ETH_RPC --broadcast --chain-id 1
		;;
	moontest)
		forge script script/01_Deploy.s.sol:Deploy --rpc-url $MOONBASE_RPC --broadcast --chain-id 1287
		;;
	*)
		echo "Please specify the chain to deploy in.";
		;;
esac
