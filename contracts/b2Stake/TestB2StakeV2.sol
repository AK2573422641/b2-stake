pragma solidity >=0.8.24;

import "./B2Stake.sol";

contract TestB2StakeV2  is  B2Stake{

    uint256 public number;

    string public name;
    

    function getUser(uint256 _pid,address _addr) external view   returns (UserInfo memory){
        return userInfos[_addr][_pid];
    }


    function getRequest(uint256 _pid,address _addr) external view   returns (Request[] memory){
            UserInfo storage user = userInfos[_addr][_pid];
            return user.requests;
    }


     function getNumber() public view returns (uint256) {
        return number;
    }

    function setNumber(uint256 _number) public {
        number = _number+6;
    }

    function setName(string memory _name) public {
        name = _name;
    }

    function getName() public view returns (string memory) {
            return name;
    }
    

   


}