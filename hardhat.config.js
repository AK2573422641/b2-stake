require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks:{
    local: {
      url: 'http://127.0.0.1:8545',
      //accounts: [process.env.LOCAL_PRIVATE_KEY]
      accounts: ['0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80','4cadbf46b66b29071cd51419babf85d4177b12310e565849a5d29be6dfdc4e23']
    }

  }
    
  
};
