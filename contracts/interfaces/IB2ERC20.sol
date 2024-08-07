// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IB2ERC20 {
    function b2TotalSupply() external view returns (uint);

    function b2BalanceOf(address owner) external view returns (uint);

    function burn(address from, uint value) external returns (bool);

    function mint(address to, uint value) external returns (bool);

}
