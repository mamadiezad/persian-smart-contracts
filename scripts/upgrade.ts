// 📦 اسکریپت آپگرید قراردادها
// بعد از تغییر کد قرارداد، این اسکریپت را اجرا کنید

import { ethers, upgrades } from 'hardhat';

async function main() {
  const proxyAddress = process.env.PROXY_ADDRESS || '';
  if (!proxyAddress) {
    console.error('❌ PROXY_ADDRESS را در .env تنظیم کنید');
    process.exit(1);
  }

  console.log(`🔄 Upgrading contract at ${proxyAddress}...`);
  const Contract = await ethers.getContractFactory('MultiSigWallet'); // یا Escrow, ReferralToken
  const upgraded = await upgrades.upgradeProxy(proxyAddress, Contract);
  await upgraded.waitForDeployment();
  console.log(`✅ Upgraded! New implementation: ${await upgrades.erc1967.getImplementationAddress(proxyAddress)}`);
}

main().catch(console.error);
