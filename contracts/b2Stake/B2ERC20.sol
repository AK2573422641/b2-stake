// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../interfaces/IB2ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract B2ERC20 is ERC20, IB2ERC20 {

    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol) public{
        
    }

    function mint(address to, uint256 value) external returns (bool)  {
       _mint(to, value);
       return true;
    }

    function burn(address from, uint256 value) external returns (bool) {
        _burn(from, value); 
        return true;
    }

    function b2TotalSupply() external view returns (uint){
        return totalSupply();
    }

    function b2BalanceOf(address owner) external view returns (uint){
        return balanceOf(owner);
    }
   
}
