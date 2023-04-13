require('dotenv').config();
const hre = require("hardhat");
const { getDefaultProvider, Wallet } = require('ethers');

async function main() {
	const privateKey = process.env.PRIVATE_KEY;

	// BSC config
	const BscProvider = getDefaultProvider("https://bsc-dataseed.binance.org/");
	const BscWallet = new Wallet(privateKey, BscProvider);
	const BscGateway = "0x304acf330bbE08d1e512eefaa92F6a57871fD895";
	const BscGas = "0x2d5d7d31F671F86C782533cc367F14109a082712";
	const BscHibiki = "0xa532cfaa916c465a094daf29fea07a13e41e5b36";

	// Deploy on BSC
	const BscBridge = await hre.ethers.getContractFactory("HibikiBridge", BscWallet);
	const bscBridge = await BscBridge.deploy(BscGateway, BscGas, BscHibiki);
	await bscBridge.deployed();
	console.log("BSC bridge deployed to", bscBridge.address);

	// Ethereum config
	const EthProvider = getDefaultProvider("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161");
	const EthWallet = new Wallet(privateKey, EthProvider);
	const EthGateway = "0x4F4495243837681061C4743b74B3eEdf548D56A5";
	const EthGas = "0x2d5d7d31F671F86C782533cc367F14109a082712";
	const EthHibiki = "0xA693032e8cfDB8115c6E72B60Ae77a1A592fe4bD";

	// Deploy on Ethereum
	const EthBridge = await hre.ethers.getContractFactory("HibikiBridge", EthWallet);
	const ethBridge = await EthBridge.deploy(EthGateway, EthGas, EthHibiki);
	await ethBridge.deployed();
	console.log("Eth bridge deployed to", ethBridge.address);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
