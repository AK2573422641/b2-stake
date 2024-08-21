// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;


import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../interfaces/IB2ERC20.sol";

/*
B2RewardPerBlock = 
方案一：自定义的奖励速度，固定值
方案二：用totalReward/blockGap,例如奖励是1000个B2,一般来说不同的时间，奖励速度是不一样的；可以连续投放奖励，即使上一个奖励机制还没有用完
        这种方案可以不用B2RewardPerBlock

rewardPerPool = totalReward*poolWeight/totalPoolWeight;得到池的奖励，然后计算每个用户的奖励，



当然也可以直接针对某个池做定向奖励，这里做一个嵌套循环处理

rewardPerUserInPool = 根据用户区块的个数以及时间来计算得到奖励；

核心方法逻辑：
每次新增区块，所有的pool的的奖励值都要全部更新一次，因为新增一个池，权重比值变更，所以奖励变少

更新每个池的权重也是这样；


质押：
本质是跟新计算上一次奖励，对每个用户来说，accRewardPerPoolToken 这个是所有用户的，每个用户自身保存一份自己已经支付的金额rewardPerPoolTokenPaid;

accRewardPerPoolToken = rewardRateINpool*(blockGap)/supply

 userReward = (accRewardPerPoolToken -rewardPerPoolTokenPaid)*用户代币数；

用户rewardPerPoolTokenPaid = accRewardPerPoolToken；


质押池：质押池没有特别的限制，每一个代币，都可以在不同的质押池中，因为如果同一种代币放在质押池中，那么解除质押的时间就不好定义了，
跟新质押时间，
1）那么原来已经可以解除质押时间的又不能解除质押了，
2）已经超过了解除质押时间了，那么新的用户需要质押怎么办，质押然后又快速解除质押，那么会对系统不稳定，也不友好，可能会有套利空间，
因为你的池子的权重是恒定的，只要一段时间是固定的



接触质押和领取奖励的业务逻辑：
1.解除质押，要求到解除质押的时间，实现对应的代币销毁
2.领取奖励：即计算质押时间



uint256 finishedB2;//已分配的 B2 数量    用户已经可以领取的 B2 数量；
uint256 pendingB2;//待领取的 B2 数量     暂定为当前已经申请解除质押，但是没有领取的 B2 数量，，如果出现了cliam,那么这个值就会减少，那么将对应的钱

unstake：将对应的B2代币的收益暂停，并且等待解锁，解锁以后才可以进行提现
withdraw:将对应的质押代币提现，跟对应的B2代币没有关系，只是将对应的请求来进行处理；

cliam:min_对应的代币，，，给用户转账



综上所述：其实B2-stake质押，和对应的pledge的质押，其实都是质押，
相同点：
1.都有存款质押，
2.都是在claim的时候获取对应的代币



不同点：
1.B2-STAKE 是动态利率，有质押区块，等到解除质押区块以后，才能提现； pledge 是固定利率，质押以后，没有解除质押的限制，可以随时提现；
2.B2-stake质押，对应的是存款质押；pledge既有存款质押，又有借款质押；
3.claim获取质押代币的方法不一样：B2-stake对应的是转发代币，pledge也可以是_mint代币



*/

/*
类比与uniswap的流动性质押的逻辑

*/

contract B2Stake  is      
    ReentrancyGuard, 
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable{

    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    address private owner;
    // 质押产生代币的地址
    IB2ERC20 public iB2ERC20;

    PoolInfo[] public poolInfoList;


     struct PoolInfo{
        // 质押代币的地址
        address stTokenAddress;
        // 质押池的权重，影响奖励分配
        uint256   poolWeight;
        // 最后一次计算奖励的区块号
        uint256 lastRewardBlock;
        // 每个质押代币累积的 B2 数量
        uint256 accB2PerST;
        // 池中的总质押代币量
        uint256 stTokenAmount;
        // 最小质押金额
        uint256 minDepositAmount;
        // 解除质押的锁定区块数
        uint256 unstakeLockedBlocks;
        //奖励的速度
        //uint256 rewardRate;

        //uint256 rewardPerPool;
    }

    //mapping(uint256 =>mapping(address => uint256)) public accRewardsPerPoolTokenStored;

    // 每个质押池的信息
   // mapping (uint256=>PoolInfo) public poolInfos;

    // 解除质押的请求信息
    struct Request{
        uint256 amount;//质押数量
        uint256 unlockBlock; //解锁区块
        //bool isFinished; //是否完成,,对于已完成的质押的，可以直接删除，减少了遍历的逻辑复杂度以及isFinish的存储
    }

    // 用户的质押信息
    struct UserInfo{
        uint256 stAmount;//用户质押的代币数量
        uint256 finishedB2;//可领取的 B2 数量，包括未到解禁区块的
        //uint256 pendingB2;//待领取的 B2 数量
        Request[] requests;//解质押请求列表
        uint256 rewardPerPoolTokenPaid;//已支付的奖励
        uint256 claimAmount;//可提现代币数量
    }

    // 用户质押信息映射关系
    mapping (address=>mapping(uint256 => UserInfo)) public  userInfos;

    //这里不存储对应的数据，只处理业务逻辑

    // 
    mapping (uint256 => mapping(Operator=>bool)) public pauseRecoverSwitch;

    //独立控制的方法列表枚举
    enum Operator{
        STAKING,
        UNSTAKING,
        CLAIMING_REWARDS
    }

    // 总的池权重
    uint256 public totalPoolWeight;

    // 奖励的总量
    uint256 public totalRewards;

    uint256 public rewardRatePerBlock;

    //区块开始时间
    uint256 public startBlock;
    //区块结束时间
    uint256 public endBlock;

    //统一产生的是用B2Token来作为一个事件，这样所有代币都可以使用
    event Stake(address indexed user,uint256 pid, uint256 amount);

    event UnStake(address indexed user,uint256 pid, uint256 amount);

    event AddPool(address  stTokenAddress,uint256 poolWeight, uint256 minDepositAmount,uint256 unstakeLockedBlocks);
    
    event Withdraw(address indexed user,uint256 _pid, uint256 _amount);
   
    event Log(string msg);


    //对应的modifier 可以进行跨库应用吗？
    function switch2Pause(uint256 pid,Operator  operator)  public onlyOwner {
        require(pauseRecoverSwitch[pid][operator] == false, "staus is pause");
        pauseRecoverSwitch[pid][operator] = true;
    }

     function switch2Recover(uint256 pid,Operator  operator)  public onlyOwner {
        require(pauseRecoverSwitch[pid][operator] == true, "staus is recover");
        pauseRecoverSwitch[pid][operator] = true;
    }

    
    

    function initialize(
        IB2ERC20 _iB2ERC20,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardRatePerBlock
    ) public initializer {
        require(_startBlock <= _endBlock && _rewardRatePerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        iB2ERC20 = _iB2ERC20;

        startBlock = _startBlock;
        endBlock = _endBlock;
        rewardRatePerBlock = _rewardRatePerBlock;

    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)
        override
    {

    }

    // TODO 测试使用
    function getUserInfo(uint _pid,address _addr) external view returns (UserInfo memory){
        return userInfos[_addr][_pid];
    }


     function poolLength() public view returns(uint256) {
        return poolInfoList.length;
    }

    //质押ETH功能
    /*
    function stakeETH (uint256 _pid) payable external nonReentrant  {
        PoolInfo storage poolInfo  = poolInfoList[_pid];
        require(poolInfo.stTokenAddress != address(0), "error address");

        //put function of check in the route contract 
        require(poolInfo.minDepositAmount<= msg.value, "sufficient amount");
        require(poolInfo.lastRewardBlock < block.number, "time pass over");
        value = msg.value;
        
        //如果多个ERC20质押，都是按照1：:1比例，应该就出问题了，这里没有找到一种方法，知道应该转化多少对应的B2Token，用预言机吗？chainlink？
        //deposit amount,the ETH is depoist to the B2Stake contract ,not the route contract 

        IWETH(IB2Stake).deposit{value: msg.value}();

         //(bool success, bytes memory data) = poolInfo.stTokenAddress.call(abi.encodeWithSelector(0x23b872dd, msg.sender, to, value));
       

        //cacultate b2 that equal to staking amount
        value = msg.value;


         //pool update
        poolInfo[accB2PerST] += value;
        poolInfo[stTokenAmount] += msg.value;


        //userInfo update
        userInfos[msg.sender][_pid].stAmount += msg.value;

        //mint b2
        mint(msg.sender, value);
        emit stake(msg.sender, _pid, msg.value);
        
    }
    */
   

    modifier onlyOwner(){
        require(msg.sender == owner, "only   owner");
        _;
    }

    //TODO  是否允许质押的时候，传入代币以及ETH，答案是不行，不同的原生币/代币，对应的pid是不一样的；
    //质押ERC20功能,代币质押
     //质押ETH功能
    function deposit (uint256 _pid,uint256 _amount ) external checkPid(_pid) /*nonReentrant */ {

        //校验当前区块是否在质押区块范围内
        require( block.number <= endBlock, "time pass over");
        console.log("_pid=%s,_amount=%s",_pid,_amount); 
        PoolInfo storage poolInfo  = poolInfoList[_pid];
        UserInfo storage user = userInfos[msg.sender][_pid];
        console.log("poolInfo.minDepositAmount=%s,poolInfo.poolWeight=%s",poolInfo.minDepositAmount,poolInfo.poolWeight); 

        //require(poolInfo.stTokenAddress != address(0), "invalid address");
        //put function of check in the route contract 
        require(poolInfo.minDepositAmount <= _amount, "sufficient amount");
        require(poolInfo.lastRewardBlock < block.number, "invalid block ");
        console.log("poolInfo.minDepositAmount=%s",poolInfo.minDepositAmount); 
        
        //transport the token to B2Stake contract,there is function that contain check,so need to check
        IERC20(poolInfo.stTokenAddress).transferFrom(msg.sender, address(this), _amount);

        _updatePool(_pid);
        console.log("updatePool"); 

        //计算该用户在最近一段时间的B2奖励  poolInfo.finishedB2 +=（poolInfo.accB2PerST-user.rewardPerPoolTokenPaid）*代币数量
        //如果是第一次质押，那么poolInfo.finishedB2 = 0，如果不是第一次质押，那么
        if(user.stAmount>0){
            user.finishedB2 += user.stAmount*(poolInfo.accB2PerST-user.rewardPerPoolTokenPaid);
        }
        console.log("user.finishedB2=%s",user.finishedB2); 

        //标注用户初始每个质押代币的奖励的基点
        user.rewardPerPoolTokenPaid =  poolInfo.accB2PerST;
        
        //pool update
        poolInfo.stTokenAmount += _amount;

        //userInfo update
        user.stAmount += _amount;
        console.log("poolInfo.stTokenAmount=%s,user.stAmount=%s,user.rewardPerPoolTokenPaid=%s",poolInfo.stTokenAmount,user.stAmount,user.rewardPerPoolTokenPaid); 
      
        emit Stake(msg.sender, _pid, _amount);
        
    }


    


    //unstake功能，计算B2的奖励，跟质押的WETH无关
    function unstake(uint256 _pid,uint256 _amount) external /*nonReentrant */ checkPid(_pid) {
        //check local amount is ennough
        require(_amount>0, "amount is zero");

        UserInfo storage user = userInfos[msg.sender][_pid]; 
        require(user.stAmount >= _amount, "sufficent amount");

        PoolInfo storage poolInfo = poolInfoList[_pid];

        //check the unstake time is enough
       // require(poolInfo.unstakeLockedBlocks<= block.number, "not finish");
        //if there is a last request which not finish ,then revert
        /*if(userInfo.requests.length>0){
            require(userInfo.requests[userInfo.requests.length-1].isFinished, "last unstake not finish");
        }*/

        //更新池总的配置
        _updatePool(_pid);

       //计算B2的奖励 ，poolInfo.finishedB2 +=（poolInfo.accB2PerST-user.rewardPerPoolTokenPaid）*代币数量,,,这个要考虑溢出嘛？
       user.finishedB2 += user.stAmount*(poolInfo.accB2PerST-user.rewardPerPoolTokenPaid);

        //更新上一次奖励的值
        user.rewardPerPoolTokenPaid = poolInfo.accB2PerST;


        //生成对应的unstake 的request
       user.requests.push(Request({ 
         amount:_amount,
         unlockBlock:block.number+poolInfo.unstakeLockedBlocks
       }));

        //更新用户的金额；解除质押，不应该减少金额，这样就出现了withdraw的时候，金额变少的情况了
        user.stAmount -= _amount;
        user.claimAmount += _amount;


        //burn b2-token   这里不考虑采用burn的方法和逻辑，只有在claim领取的时候，才会将B2-token  transfer到用户这里
        //_burn(msg.sender, _amount);


        //caculate the poolInfo
        //poolInfo[accB2PerST] -= _amount;

        //transferFrom erc20 to the msg.sender

        //add the record of the request 

        //update amount of userInfo and poolInfo
    }


    //直接将对应的可提现代币转入到用户地址
    function withdraw(uint256 _pid, uint256 _amount) external  checkPid(_pid){
        require(_amount>0, "_amount is zero");
        UserInfo storage user = userInfos[msg.sender][_pid];
        user.claimAmount -= _amount;
        IERC20(poolInfoList[_pid].stTokenAddress).transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _pid, _amount);

    }


    //计算对应用户当前可以领取的奖励
    function claim(uint256 _pid) external  checkPid(_pid){
        //遍历request[],计算用户可领取的B2奖励
        UserInfo storage user = userInfos[msg.sender][_pid];
        Request [] storage requests = user.requests;
        uint length = requests.length;

        // 这个地方可以做一个优化，因为request的时间是递增的，那么下表为0的request是最容易得到的，如果i=3,requests[3].unlockBlock <= block.number
        //requests[4].unlockBlock 就不用看了
        //另外还可以采用一个覆盖的方案，因为已经claim的数据要被移除，那么可以覆盖掉


        if(length > 0){
            uint totalAmount ;
            uint index;
            for(uint i = 0; i<length; i++){
                if(requests[i].unlockBlock <= block.number){
                    totalAmount += requests[i].amount;
                    index = i;
                }else{
                    break;
                }
            }


             //找到了index，把多余的request移除,只能通过覆盖，然后pop（）的方式，因为push()和pop（）方法，都是处理的末端数据

            if(index > 0 && index != length-1){
                for(uint j = 0;j <=index;j++){
                     requests[j] = requests[index+1+j];
                }
                for(uint k = 0; k <length-index;k++){
                    requests.pop(); 
                }

            }


            // 用户可以领取的奖励
            user.finishedB2 -= totalAmount;

            //给用户转账
            //IERC20(iB2ERC20).transfer(msg.sender, totalAmount);
            //应该是直接给用户mint
            iB2ERC20.mint(msg.sender, totalAmount);

        }

       
        


    }


    function balanceOf(address _owner,uint256 _pid) external view returns (uint256) {
        return userInfos[_owner][_pid].stAmount;

    }



    // TODO need to calculate the totalWeight and the totalAmount
    // TODO
    function addPool(uint256 _minDepositAmount,address _stTokenAddress,uint256 _poolWeight,uint256 _unstakeLockedBlock) external  returns(bool){
        require(_stTokenAddress != address(0), "error address");


        require(_minDepositAmount >0, "minDepositAmount is zero");

        //check the stTokenAddress is not in the poolInfoList
        // for(uint256 i = poolInfoList.length;i >0; i--){
        //     if(poolInfoList[i-1].stTokenAddress == _stTokenAddress){
        //         PoolInfo storage poolInfo = poolInfoList[i-1];
        //         poolInfo.minDepositAmount = _minDepositAmount;
        //         poolInfo.unstakeLockedBlock = _unstakeLockedBlock;
        //         poolInfo.poolWeight = _poolWeight;
        //         return true;
        //     }
        // }

        //TODO   calcuate the lastRewardBlock,update pool
        // update 现存的pool的accB2PerST,跟新用户的stAmount

        uint256 poolLength =   poolLength();
        for(uint i = 0;i <poolLength;i++){
            _updatePool(i);
        }


        uint256 lastRewardBlock = block.number > startBlock ? block.number: startBlock;
        totalPoolWeight += _poolWeight;
        
        //add poolInfo
        poolInfoList.push(PoolInfo({

            stTokenAddress: _stTokenAddress,
            poolWeight: _poolWeight,
            lastRewardBlock:lastRewardBlock,
            accB2PerST: 0,
            stTokenAmount: 0,
            minDepositAmount: _minDepositAmount,
            unstakeLockedBlocks: _unstakeLockedBlock
     
        }));
       // emit AddPool(_stTokenAddress, _poolWeight, _minDepositAmount, _unstakeLockedBlock);
        return true;
    }

    modifier checkPid(uint256 _pid){
        require(_pid < poolInfoList.length, "invalid pid");
        _;
    }

    modifier checkUnstakeLockedBlocks(uint256 _pid){
        require(poolInfoList[_pid].unstakeLockedBlocks > block.number, "invalid block");
        _;

    }
      
    function updatePool(uint256 _minDepositAmount,uint256 _pid ,uint256 _unstakeLockedBlock) external onlyOwner checkPid(_pid) returns(bool){
        poolInfoList[_pid].minDepositAmount = _minDepositAmount;
        poolInfoList[_pid].unstakeLockedBlocks = _unstakeLockedBlock;
        return true;

    }

    //update the poolInfo reward
    function _updatePool(uint256 _pid)internal checkPid(_pid) {
        PoolInfo storage poolInfo = poolInfoList[_pid];
        uint256 blockNum = block.number;
        uint256 lastRewardBlock = poolInfo.lastRewardBlock;
        console.log("lastRewardBlock=%s,blockNum=%s",lastRewardBlock,blockNum); 

        if(lastRewardBlock >= blockNum){
            return;
        }

        //caculate the rewardPerPoolWeight
       //(bool success1,uint256 rewardPerPoolWeight) = Math.tryMul(calculateTotalReward(lastRewardBlock,blockNum), totalPoolWeight);
       (bool success1,uint256 rewardPerPoolWeight) = calculateTotalReward(lastRewardBlock,blockNum).tryDiv(totalPoolWeight);
       require(success1,"rewardPerPoolWeight overflow");

        console.log("rewardPerPoolWeight=%s",rewardPerPoolWeight);

       (bool success2,uint256 rewardPerPool) = rewardPerPoolWeight.tryMul(poolInfo.poolWeight);
       require(success2,"rewardPerPoolWeight*(poolInfo.poolWeight) overflow");

        console.log("rewardPerPool=%s",rewardPerPool);
       //将计算好的每个pool对应的本次奖励
        console.log("poolInfo.stTokenAmount=%s",poolInfo.stTokenAmount);
       if(poolInfo.stTokenAmount > 0){
            // TODO 这里有一个问题，就是如果两个数值整除，结果可能是0，所以很多场景是需要先
            // 乘以10的18次方，然后再除以，这样就不会出现0的情况
            (bool success3,uint256 rewardPerToken) =  rewardPerPool.tryDiv(poolInfo.stTokenAmount);
            require(success3,"rewardPerPool/stTokenAmount overflow");
            (bool success4,uint256 newAccB2PerST) = rewardPerToken.tryAdd(poolInfo.accB2PerST);
            require(success4,"poolInfo.rewardPerToken+rewardPerToken overflow");
            poolInfo.accB2PerST = newAccB2PerST;
       }

       poolInfo.lastRewardBlock = blockNum;
       console.log("poolInfo.lastRewardBlock=%s,poolInfo.accB2PerST=%s",poolInfo.lastRewardBlock,poolInfo.accB2PerST);
       


    }



    //TODO 这个地方没有办法找到一个时间段内，这个池固定的奖励金额，因为生产奖励的速率，是按照总体的奖励的速率，计算出来的
    //不是按照某个池计算出来的，并且这个奖励的金额随着新增池子，也会不断的变化，而且每个池子的权重也会不断发生变化；所以目前采用的方案，就是采用
    //每次有池子变化，或者池权重变更，以及对应的新增质押，解除质押，都会造成accB2PerST的更新，
    // updateRewardInPool(uint256 _pid) internal {
    //     //根据当前的
    //     UserInfo storage user = userInfos[msg.sender][_pid];


    // }

    // TODO 引入了一个新的变量指针 PoolInfo storage poolInfo = poolInfoList[_pid];
    // 不过减少了计算每个池的总奖励计算
    //function updateAccB2PerST(uint256 _pid) external  checkPid(_pid){
    //    PoolInfo storage poolInfo = poolInfoList[_pid];


    ///}


    //后期对于区块的代码逻辑，需要前后都进行校验
    function calculateTotalReward(uint256 _from, uint256 _to) internal view returns (uint256 ) {
        require(_from < _to, "invalid block range");
        
        // 确保 _from 不小于 startBlock
        if (_from < startBlock) {
            _from = startBlock;
        }

        // 确保 _to 不大于 endBlock
        if (_to > endBlock) {
            _to = endBlock;
        }

        // 再次确保 _from 小于等于 _to
        require(_from <= _to, "_to must be greater than or equal to _from");

        console.log("_to - _from=%s",_to - _from);
        // 计算奖励
        (bool success1, uint256 rewardRatePerBlocke18) = rewardRatePerBlock.tryMul(1e18);
        require(success1, "rewardRatePerBlock.tryMul(1e18) overflow");
        (bool success2,uint256 totalReward) = rewardRatePerBlocke18.tryMul(_to - _from);
        require(success2, "rewardRatePerBlock * (_to - _from) overflow");
        console.log("totalReward=%s",totalReward);
        return totalReward;
}
        
    




}
