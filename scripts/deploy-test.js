const hre = require("hardhat");
const { getDefaultProvider, Wallet } = require('ethers');

async function main() {
	const privateKey = process.env.EVM_PRIVATE_KEY;

	// BSC Testnet config
	const BscTestnetProvider = getDefaultProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
	const BscTestnetWallet = new Wallet(privateKey, BscTestnetProvider);
	const BscTestGateway = "0x4D147dCb984e6affEEC47e44293DA442580A3Ec0";
	const BscTestGas = "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6";
	const BscHibiki = "0xeC12d79597967aeBAf9b1bE75A8D51D29424DE15";

	// Deploy on BSC Testnet
	const BscTestBridge = await hre.ethers.getContractFactory("HibikiBridge", BscTestnetWallet);
	const bscTestBridge = await BscTestBridge.deploy(BscTestGateway, BscTestGas, BscHibiki);
	await bscTestBridge.deployed();
	console.log("BSC Testnet bridge deployed to", bscTestBridge.address);

	// Moonbeam testnet config
	const MoonTestProvider = getDefaultProvider("https://rpc.testnet.moonbeam.network");
	const MoonTestWallet = new Wallet(privateKey, MoonTestProvider);
	const MoonTestGateway = "0x5769D84DD62a6fD969856c75c7D321b84d455929";
	const MoonTestGas = "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6";
	const MoonHibiki = "0x89FaCEBDC11a879ed2096889621DB9f4D2ED5473";

	// Deploy on Moonbeam testnet
	const MoonTestBridge = await hre.ethers.getContractFactory("HibikiBridge", MoonTestWallet);
	const moonTestBridge = await MoonTestBridge.deploy(MoonTestGateway, MoonTestGas, MoonHibiki);
	await moonTestBridge.deployed();
	console.log("Moonbeam Testnet bridge deployed to", moonTestBridge.address);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
