const { ethers, upgrades } = require("hardhat");


let B2StakeProxy ;
async function deploy() {

    console.log("B2StakeProxy deployed start:");
    [owner, otherAccount] = await ethers.getSigners();
    const B2ERC20 = await ethers.getContractFactory("B2ERC20");  
    B2ERC20Address = await B2ERC20.connect(owner).deploy("B2-TOKEN", "B2T");
    await B2ERC20Address.waitForDeployment();

    console.log("B2StakeProxy deployed start");
  const B2Stake = await ethers.getContractFactory("TestB2Stake");
  //await upgrades.deployProxy(MyContract, [/* 初始化参数 */], { initializer: "initialize" });
  //相当于initialize 方法作为构造函数，开始用来部署的时候，需要用他来做构造函数接受数据
   B2StakeProxy = await upgrades.deployProxy(B2Stake, [B2ERC20Address.target,1,10000,ethers.parseEther('0.01')], { initializer: "initialize" });

  //<!-- await platform.deployed(); console.log("CrowdfundingPlatform deployed to:", platform.address);  updateBY leo-->
  await B2StakeProxy.waitForDeployment();
 console.log("B2StakeProxy.target deployed to:", B2StakeProxy.target);
 console.log("B2StakeProxy.address deployed to:", B2StakeProxy.address);
 console.log("B2Stake.address deployed to:", B2Stake.address);


 await  B2StakeProxy.setName("deploy");
 await  B2StakeProxy.setNumber(8);
 let number  = await  B2StakeProxy.getNumber();
 console.log("number:", number);
 let name  = await  B2StakeProxy.getName();
 console.log("name:", name);
}




const upgrade = async()=>{

  console.log('开始了');
  let number  = await B2StakeProxy.getNumber();
  console.log("number before:", number);
  let name  = await  B2StakeProxy.getName();
  console.log(" name before:", name);

 const TestB2StakeV2 = await  ethers.getContractFactory("TestB2StakeV2");

 //const platform = await upgrades.upgradeProxy(CrowdfundingPlatformProxy.target, CrowdfundingPlatformV2);
  B2StakeProxy = await upgrades.upgradeProxy(B2StakeProxy, TestB2StakeV2);
 console.log("TestB2StakeV2 upgraded，upgrade to address: ",B2StakeProxy.address);
 console.log("TestB2StakeV2 upgraded，upgrade to target: ",B2StakeProxy.target);

 //await platform.waitForDeployment();
//console.log("CrowdfundingPlatformV2 deployed to:", platform.target);

 number  = await B2StakeProxy.getNumber();
console.log("number after:", number);

 
 name  = await  B2StakeProxy.getName();
console.log("name after:", name);


await B2StakeProxy.setNumber(3);
number  = await B2StakeProxy.getNumber();
console.log("number after again:", number);
 
}

async function main() {
  
  
  await deploy();
  await upgrade();
}

main();



/*

// test/update-test.ts
const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');


let myLogicV1;
let myLogicV2;

describe('uups mode upgrade', function () {
  it('deploys', async function () {
    const MyLogicV1 = await ethers.getContractFactory('MyLogicV1');
      myLogicV1 = (await upgrades.deployProxy(MyLogicV1, {kind: 'uups'}));
      console.log(myLogicV1.address);
  })
  it('myLogicV1 set', async function () {
    await myLogicV1.SetLogic("aa", 1);
    expect((await myLogicV1.GetLogic("aa")).toString()).to.equal('1');
  })
  it('upgrades', async function () {
    const MyLogicV2 = await ethers.getContractFactory('MyLogicV2');
      myLogicV2 = (await upgrades.upgradeProxy(myLogicV1, MyLogicV2));
      console.log(myLogicV2.address);
  })
  it('myLogicV2 get', async function () {
      expect((await myLogicV2.GetLogic("aa")).toString()).to.equal('101');
  })
})

*/