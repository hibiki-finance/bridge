# Hibiki Token Bridge

This is the smart contract to bridge Hibiki tokens between the available blockchains.

The bridge is built upon the [Axelar SDK](https://docs.axelar.dev/).

This repository has configuration for both Hardhat and Foundry. You can check out information about the later at their [book](https://book.getfoundry.sh/).

## Environment variables

You need to set up environment variables to run the scripts.

You can run the hardhat script `setup-env.js` with `npx hardhat run scripts/setup-env.js` to setup the base `.env` file from the example, there you can configure the private key with which to sign transactions.

Forge bash scripts load the environment file, hardhat scripts use dotenv.

## Deploy

You can find the forge deployment script on the root. You have to run it with `bash` and pass as a single parameter the network shorthand in lower case, such as `bash deploy.sh eth`.

Hardhat deployment scripts are found in the folder `scripts` and are run with `npx hardhat run scripts/[name].js`. More info at their [documentation](https://hardhat.org/hardhat-runner/docs/advanced/scripts).

Hardhat `deploy-test.js` deploys the bridge contract to the BSC Testnet and Moonbase (Moonbeam testnet) at the same time. Those two chains are the ones used to test the bridge on a test environment.

Hardhat `deploy.js` deploys the bridge contract to the BNB Smart Chain and Ethereum mainnet at the same time.

## Testing

Tests are written using Foundry. You can run them with the command `forge test` or with `npm run test`.

## Coverage

You need `lcov` installed to run the test coverage script.

You may run `bash coverage.sh` or `npm run coverage`.

After running it you will find it on a folder called `coverage` in the root.

