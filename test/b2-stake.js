const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("B2-stake", function () {

  let B2ERC20Address;  
  let B2StakeAddress;  
  let contractAddress;
  let owner;
  let otherAccount;
 

  beforeEach(async () => {

    [owner, otherAccount] = await ethers.getSigners();
    // console.log("owner: ", owner.address);
    // console.log("owner: ", owner);

    const B2ERC20 = await ethers.getContractFactory("B2ERC20");  
    B2ERC20Address = await B2ERC20.connect(owner).deploy("B2-TOKEN", "B2T");
    await B2ERC20Address.waitForDeployment();


    const stAddressFactory = await ethers.getContractFactory("B2ERC20");  
    stAddress = await stAddressFactory.connect(owner).deploy("ST-TOKEN", "ST");
    await stAddress.waitForDeployment();
    console.log("stAddress: ", stAddress.target);
    
    contractAddress = stAddress;
    console.log("contractAddress: ", contractAddress.target);
    //await contractAddress.mint(owner.address,10e19);
    //await contractAddress.mint(otherAccount.address,2e20);
    //const owner_amount =await contractAddress.balanceOf(owner.address);
    //const otherAccount_amount =await contractAddress.balanceOf(otherAccount.address);
    //console.log("owner_balance: ", owner_amount);
    //console.log("otherAccount_balance: ", otherAccount_amount);
    //console.log("otherAccount_balance: ", contractAddress.balanceOf(otherAccount.address));


    const B2Stake = await ethers.getContractFactory("TestB2Stake");  
    // B2StakeAddress = await B2Stake.deploy(B2ERC20Address.addr,0,10,ethers.parseEther('100000000'));  用address不行，用target
    B2StakeAddress = await B2Stake.connect(owner).deploy();  
    await B2StakeAddress.waitForDeployment();
    await B2StakeAddress.connect(owner).initialize(B2ERC20Address.target,1,10000,ethers.parseEther('0.01'));

    console.log("foreach end : ");
    
    //console.log("B2StakeAddress Contract deploying... ",B2StakeAddress.target);

    // Contracts are deployed using the first signer/account by default
     

  });

  


  describe("addPool", function () {

        //对于数据的返回值，一般都是不用做测试的，因为测试了以后，返回值也是不正确的；
        /*it("return ture", async function () {  
          const result  = await  B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'), contractAddress.target, 1, 200);
          console.log("result ",result);  
          expect(result).to.equal(1); 
        });*/
        

            
        it("should return error address", async function () {  
            //const { B2StakeAddress, B2ERC20Address, owner, otherAccount } = await loadFixture(deployOneYearLockFixture);
            await expect(  
              B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'), '0x0000000000000000000000000000000000000000', 1, 200)  
          ).to.be.revertedWith("error address")
        });   
      

        it("Should not allow non-owner to add", async function () {
          // 作为非合约所有者调用 add 方法应该失败
          //如果只是需要一个简单的权限验证，是不需要用Ownable方法的，这样测试也比较好测试一点
          //const errMsg = await B2StakeAddress.connect(otherAccount).addPool(ethers.parseEther('0.001'),contractAddress,1,200);
          //console.log("errMsg:", errMsg);
          //expect(errMsg).to.include('OwnableUnauthorizedAccount'); 
          //B2StakeAddress.connect(owner).addPool(ethers.parseEther('0.01'),contractAddress.target,1,200);

          await expect( 
            B2StakeAddress.connect(otherAccount).addPool(ethers.parseEther('0.1'), contractAddress.target, 1, 200)  
           ).to.be.revertedWith("only   owner");

          /*    await expect(  
                B2StakeAddress.connect(otherAccount).addPool(ethers.parseEther('0.1'),contractAddress.target,1,200)  
            ).to.be.revertedWith("only   owner");*/
         
          
         });

        it("should return minDepositAmount is zero", async function () {  
            //const { B2StakeAddress, B2ERC20Address, owner, otherAccount } = await loadFixture(deployOneYearLockFixture);
            await expect( 
              
              B2StakeAddress.connect(owner).addPool(0, contractAddress.target, 1, 200)  
          ).to.be.revertedWith("minDepositAmount is zero");  
        });

        //每次调用合约方法，用await
        it("Should add a pool correctly if all parameters are valid", async function () {  
          await B2StakeAddress.connect(owner).addPool(ethers.parseEther('0.001'),contractAddress.target,1,200);
           const pool =await B2StakeAddress.poolInfoList(0);
          expect(pool.minDepositAmount).to.equal(ethers.parseEther('0.001'));
          expect(pool.stTokenAddress).to.equal(contractAddress);
          //expect(pool.stTokenAddress).to.equal(contractAddress);
          expect(pool.poolWeight).to.equal(1);
          //expect(pool.unstakeLockedBlock).to.equal(200); 
          //pool.unstakeLockedBlock 是一个 BigNumber,断言库不支持 BigNumber，需要做调整
          //expect(pool.unstakeLockedBlock).to.bignumber.equal(ethers.BigNumber.from(200));
        });
      });

      describe("deposit", function () {

            //对于数据的返回值，一般都是不用做测试的，因为测试了以后，返回值也是不正确的；
            it("Should revert if deposit amount is less than minimum deposit amount", async function () {
              await B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'),contractAddress.target,1,200);

              await contractAddress.mint(otherAccount.address,ethers.parseEther('1'));
              
              const pool =await B2StakeAddress.poolInfoList(0);
              console.log("poolWeight: ", pool.poolWeight);
              console.log("stTokenAddress: ", pool.stTokenAddress);
              console.log("minDepositAmount: ", pool.minDepositAmount);
              await expect(
                B2StakeAddress.connect(otherAccount).deposit(0, ethers.parseEther("0.5"))
              ).to.be.revertedWith("sufficient amount");
          });

          it("Should revert if pid is in the poll ", async function () {
            await B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'),contractAddress.target,1,200);

            
            const pool =await B2StakeAddress.poolInfoList(0);
            console.log("poolWeight: ", pool.poolWeight);
            console.log("stTokenAddress: ", pool.stTokenAddress);
            console.log("minDepositAmount: ", pool.minDepositAmount);
            await expect(
              B2StakeAddress.connect(otherAccount).deposit(1, ethers.parseEther("0.5"))
            ).to.be.revertedWith("invalid pid");
        });


         
      
          it("Should deposit and update user and pool state correctly", async function () {

              // 添加一个池子
              await B2StakeAddress.connect(owner).addPool(ethers.parseEther('0.01'),contractAddress.target,1,200);

              //给otherAccount用户mint token
              const amount = ethers.parseEther("2");
              await contractAddress.mint(otherAccount.address,amount);

              const initialBalance = await contractAddress.balanceOf(otherAccount.address);
              console.log("JS_initialBalance: ", initialBalance);
              console.log("JS_amount: ", amount);

              // 授权合约从otherAccount账户中转移 token
              await contractAddress.connect(otherAccount).approve(B2StakeAddress.target, amount);
              const approve_amount = await contractAddress.allowance(otherAccount.address,B2StakeAddress.target)

              console.log("JS_approve_amount: ", approve_amount );
              // Perform the deposit
              await B2StakeAddress.connect(otherAccount).deposit(0, amount);

              const pool = await B2StakeAddress.poolInfoList(0);
              
              const user = await B2StakeAddress.getUserInfo(0,otherAccount.address);

              const finalBalance = await contractAddress.balanceOf(otherAccount.address);
              console.log("user.stAmount: ", user.stAmount );
              console.log("pool.stTokenAmount: ", pool.stTokenAmount );
              console.log("finalBalance: ", finalBalance );
      
              expect(user.stAmount).to.equal(amount);
      
              expect(pool.stTokenAmount).to.equal(amount);

              //对应的金额
              expect(finalBalance).to.equal(initialBalance-(amount));
          });
      

          /*it("Should distribute rewards correctly on subsequent deposits", async function () {
              await B2StakeAddress.add(
                  cupToken.target,
                  false,
                  1000,
                  ethers.parseEther("1"),
                  ethers.parseEther("1")
              );
      
              const rewardAmount = BigInt(10**37);
              
              await rewardToken.mint(owner.address,rewardAmount);
      
              // 授权合约从所有者账户中转移 RewardToken
              await rewardToken.approve(maxStake.target, rewardAmount);
      
              await maxStake.fund(rewardAmount);
      
              const amount = ethers.parseEther("10");
              await cupToken.mint(owner.address, amount*BigInt(2));
              await cupToken.approve(maxStake.target, amount*BigInt(2));
      
              // Initial deposit
              await maxStake.deposit(0, amount);
      
              // Increase time to accumulate rewards
              await ethers.provider.send("evm_increaseTime", [1000]);
              await ethers.provider.send("evm_mine");
      
              const balance = await cupToken.balanceOf(owner.address);
              console.log("amount,cup balance",amount,balance);
              // Second deposit
              await maxStake.deposit(0, amount);
      
              const userInfo = await maxStake.getUserInfo(0, owner.address);
              expect(userInfo.stAmount).to.equal(amount*BigInt(2));
      
              const reward = await rewardToken.balanceOf(owner.address);
              expect(reward).to.be.gt(0); // Should be greater than zero as rewards should have been accumulated
          });*/
        

            
       
      });


      describe("unstake", function () {

        //对于数据的返回值，一般都是不用做测试的，因为测试了以后，返回值也是不正确的；
        it("Should revert if amount is zero", async function () {
          await B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'),contractAddress.target,1,200);
          let amount = ethers.parseEther("2");
          //先deposit
          await contractAddress.mint(otherAccount.address,amount);
          await contractAddress.connect(otherAccount).approve(B2StakeAddress.target, amount);
          await B2StakeAddress.connect(otherAccount).deposit(0, amount);
         
          await expect(
            B2StakeAddress.connect(otherAccount).unstake(0, 0)
          ).to.be.revertedWith("amount is zero");
         });

        it("Should revert if sufficent amount ", async function () {
          await B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'),contractAddress.target,1,200);
          let amount = ethers.parseEther("2");
          //先deposit
          await contractAddress.mint(otherAccount.address,amount);
          await contractAddress.connect(otherAccount).approve(B2StakeAddress.target, amount);
          await B2StakeAddress.connect(otherAccount).deposit(0, amount);

          await expect(
            B2StakeAddress.connect(otherAccount).deposit(0, ethers.parseEther("2.5"))
          ).to.be.revertedWith("sufficent amount");
        });


     
  
      it("Should unstake and update user and pool state correctly", async function () {

        await B2StakeAddress.connect(owner).addPool(ethers.parseEther('1'),contractAddress.target,1,200);
        let despsitAmount = ethers.parseEther("2");
        let unstakeAmount = ethers.parseEther("1.5");
        //先deposit
        await contractAddress.mint(otherAccount.address,despsitAmount);
        await contractAddress.connect(otherAccount).approve(B2StakeAddress.target, despsitAmount);
        await B2StakeAddress.connect(otherAccount).deposit(0, despsitAmount);

        let pool = await B2StakeAddress.poolInfoList(0);
        let user = await B2StakeAddress.getUserInfo(0,otherAccount.address);
        let initailUserAmount = user.stAmount
        let initialClaimAmount = user.claimAmount;

        const initialBlockNumber = await ethers.provider.getBlockNumber();
        for(let k = 0;k <100; k++){
          await network.provider.send("evm_mine", []);
        }
        const newBlockNumber = await ethers.provider.getBlockNumber();
        console.log("JS_initialBlockNumber,newBlockNumber: ", initialBlockNumber,newBlockNumber);


        //unstake
        await B2StakeAddress.connect(otherAccount).unstake(0, unstakeAmount);
        //对于前端来说，之前获取的是值，而不是指针，所以要重新获取一次
        user = await B2StakeAddress.getUserInfo(0,otherAccount.address);
        let finalUserAmount = user.stAmount
        let fianlClaimAmount = user.claimAmount;
        //初始用户金额 - unstake金额 = 剩余金额
        console.log("JS_initailUserAmount,unstakeAmount,finalUserAmount: ", initailUserAmount,unstakeAmount,finalUserAmount );
        expect(finalUserAmount).to.equal(initailUserAmount-unstakeAmount);
        console.log("JS_user.finishedB2: ", user.finishedB2 );
        expect(user.finishedB2).to.greaterThan(0);
        //let request  = await B2StakeAddress.getRequest(0,otherAccount);
        //提交解除质押金额
        //expect(request(0).amount).to.equal(unstakeAmount);
        console.log("JS_fianlClaimAmount,initialClaimAmount,unstakeAmount: ", fianlClaimAmount,initialClaimAmount,unstakeAmount );
        expect(fianlClaimAmount).to.equal(initialClaimAmount+unstakeAmount);
       
      });
        
   
  });

});