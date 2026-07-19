import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import dotenv from 'dotenv';
dotenv.config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || '0000000000000000000000000000000000000000000000000000000000000000';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    hardhat: {},
    polygon: {
      url: process.env.POLYGON_RPC || 'https://polygon-rpc.com',
      accounts: [PRIVATE_KEY],
      chainId: 137,
    },
    bsc: {
      url: process.env.BSC_RPC || 'https://bsc-dataseed.binance.org',
      accounts: [PRIVATE_KEY],
      chainId: 56,
    },
    ethereum: {
      url: process.env.ETH_RPC || 'https://eth-mainnet.g.alchemy.com/v2/demo',
      accounts: [PRIVATE_KEY],
      chainId: 1,
    },
  },
};

export default config;
