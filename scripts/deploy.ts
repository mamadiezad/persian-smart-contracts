import { ethers, upgrades } from 'hardhat';

async function main() {
  console.log('Deploying Persian Smart Contracts...\n');

  console.log('Deploying MultiSigWallet...');
  const MultiSig = await ethers.getContractFactory('MultiSigWallet');
  const multisig = await upgrades.deployProxy(MultiSig, [['0x0000000000000000000000000000000000000000'], 1, 0], {
    kind: 'uups', initializer: 'initialize',
  });
  await multisig.waitForDeployment();
  console.log('MultiSigWallet:', await multisig.getAddress());

  console.log('Deploying Escrow...');
  const Escrow = await ethers.getContractFactory('Escrow');
  const escrow = await upgrades.deployProxy(Escrow, ['0x0000000000000000000000000000000000000000', 250], {
    kind: 'uups', initializer: 'initialize',
  });
  await escrow.waitForDeployment();
  console.log('Escrow:', await escrow.getAddress());

  console.log('Deploying ReferralToken...');
  const Token = await ethers.getContractFactory('ReferralToken');
  const token = await upgrades.deployProxy(
    Token,
    ['PersianToken', 'PRS', ethers.parseEther('1000000'), ethers.parseEther('10'), 100, '0x0000000000000000000000000000000000000000'],
    { kind: 'uups', initializer: 'initialize' }
  );
  await token.waitForDeployment();
  console.log('ReferralToken:', await token.getAddress());

  console.log('\nAll deployed!');
  console.log('MultiSig:', await multisig.getAddress());
  console.log('Escrow:', await escrow.getAddress());
  console.log('Token:', await token.getAddress());
}

main().catch(console.error);
