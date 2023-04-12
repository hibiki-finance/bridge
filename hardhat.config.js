require('hardhat-gas-reporter');
require('solidity-coverage');
require('@nomiclabs/hardhat-ethers');
const pk = process.env.EVM_PRIVATE_KEY;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	solidity: {
		version: '0.8.19',
		settings: {
			evmVersion: process.env.EVM_VERSION || 'london',
			optimizer: {
				enabled: true,
				runs: 200,
				details: {
					peephole: true,
					inliner: true,
					jumpdestRemover: true,
					orderLiterals: true,
					deduplicate: true,
					cse: true,
					constantOptimizer: true,
					yul: true,
					yulDetails: {
						stackAllocation: true,
					},
				},
			},
		}
	},
	networks: {
		bsctest: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
			chainId: 97,
			accounts: [pk]
		},
		moontest: {
			url: "https://rpc.testnet.moonbeam.network",
			chainId: 1287,
			accounts: [pk]
		},
		eth: {
			url: "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
			chainId: 1,
			gasPrice: "auto",
			accounts: [pk]
		},
		bsc: {
			url: "https://bsc-dataseed.binance.org/",
			chainId: 56,
			accounts: [pk]
		},
	},
	paths: {
		sources: './contracts',
		tests: "./test",
		cache: "./cache",
		artifacts: "./artifacts"
	},
};
