const { ethers, upgrades } = require("hardhat");

async function main() {
  const B2Stake = await ethers.getContractFactory("B2Stake");
  const B2StakeProxy = await upgrades.upgradeProxy("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0", B2Stake);
  console.log("B2StakeV2 upgraded，upgrade to ",B2StakeProxy.address);

  console.log("B2StakeV2 upgraded");
}

main();