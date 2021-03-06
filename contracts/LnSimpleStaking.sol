// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./IERC20.sol";
import "./LnAdmin.sol";
import "./LnOperatorModifier.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./LnAccessControl.sol";
import "./LnLinearStaking.sol";
import "./SafeDecimalMath.sol";

contract LnRewardCalculator {
    using SafeMath for uint256;

    struct UserInfo {
        uint256 reward;
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint256 amount;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    uint256 public rewardPerBlock;

    PoolInfo public mPoolInfo;
    mapping(address => UserInfo) public userInfo;

    uint256 public startBlock;
    uint256 public remainReward;
    uint256 public accReward;

    constructor(uint256 _rewardPerBlock, uint256 _startBlock) public {
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        mPoolInfo.lastRewardBlock = startBlock;
    }

    function _calcReward(uint256 curBlock, address _user)
        internal
        view
        returns (uint256)
    {
        PoolInfo storage pool = mPoolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.amount;
        if (curBlock > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = curBlock.sub(
                pool.lastRewardBlock,
                "cr curBlock sub overflow"
            );
            uint256 curReward = multiplier.mul(rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(
                curReward.mul(1e20).div(lpSupply)
            );
        }
        uint256 newReward = user.amount.mul(accRewardPerShare).div(1e20).sub(
            user.rewardDebt,
            "cr newReward sub overflow"
        );
        return newReward.add(user.reward);
    }

    function rewardOf(address _user) public view returns (uint256) {
        return userInfo[_user].reward;
    }

    function amount() public view returns (uint256) {
        return mPoolInfo.amount;
    }

    function amountOf(address _user) public view returns (uint256) {
        return userInfo[_user].amount;
    }

    function getUserInfo(address _user)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            userInfo[_user].reward,
            userInfo[_user].amount,
            userInfo[_user].rewardDebt
        );
    }

    function getPoolInfo()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            mPoolInfo.amount,
            mPoolInfo.lastRewardBlock,
            mPoolInfo.accRewardPerShare
        );
    }

    function _update(uint256 curBlock) internal {
        PoolInfo storage pool = mPoolInfo;
        if (curBlock <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        if (lpSupply == 0) {
            pool.lastRewardBlock = curBlock;
            return;
        }
        uint256 multiplier = curBlock.sub(
            pool.lastRewardBlock,
            "_update curBlock sub overflow"
        );
        uint256 curReward = multiplier.mul(rewardPerBlock);

        remainReward = remainReward.add(curReward);
        accReward = accReward.add(curReward);

        pool.accRewardPerShare = pool.accRewardPerShare.add(
            curReward.mul(1e20).div(lpSupply)
        );
        pool.lastRewardBlock = curBlock;
    }

    function _deposit(
        uint256 curBlock,
        address _addr,
        uint256 _amount
    ) internal {
        PoolInfo storage pool = mPoolInfo;
        UserInfo storage user = userInfo[_addr];
        _update(curBlock);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accRewardPerShare)
                .div(1e20)
                .sub(user.rewardDebt, "_deposit pending sub overflow");
            if (pending > 0) {
                reward(user, pending);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.add(_amount);
            pool.amount = pool.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e20);
    }

    function _withdraw(
        uint256 curBlock,
        address _addr,
        uint256 _amount
    ) internal {
        PoolInfo storage pool = mPoolInfo;
        UserInfo storage user = userInfo[_addr];
        require(user.amount >= _amount, "_withdraw: not good");
        _update(curBlock);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e20).sub(
            user.rewardDebt,
            "_withdraw pending sub overflow"
        );
        if (pending > 0) {
            reward(user, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(
                _amount,
                "_withdraw user.amount sub overflow"
            );
            pool.amount = pool.amount.sub(
                _amount,
                "_withdraw pool.amount sub overflow"
            );
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e20);
    }

    function reward(UserInfo storage user, uint256 _amount) internal {
        if (_amount > remainReward) {
            _amount = remainReward;
        }
        remainReward = remainReward.sub(
            _amount,
            "reward remainReward sub overflow"
        );
        user.reward = user.reward.add(_amount);
    }

    function _claim(address _addr) internal {
        UserInfo storage user = userInfo[_addr];
        if (user.reward > 0) {
            user.reward = 0;
        }
    }
}

contract LnRewardCalculatorTest is LnRewardCalculator {
    constructor(uint256 _rewardPerBlock, uint256 _startBlock)
        public
        LnRewardCalculator(_rewardPerBlock, _startBlock)
    {}

    function deposit(
        uint256 curBlock,
        address _addr,
        uint256 _amount
    ) public {
        _deposit(curBlock, _addr, _amount);
    }

    function withdraw(
        uint256 curBlock,
        address _addr,
        uint256 _amount
    ) public {
        _withdraw(curBlock, _addr, _amount);
    }

    function calcReward(uint256 curBlock, address _user)
        public
        view
        returns (uint256)
    {
        return _calcReward(curBlock, _user);
    }
}

contract LnSimpleStaking is
    LnAdmin,
    Pausable,
    ILinearStaking,
    LnRewardCalculator
{
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;

    IERC20 public linaToken; // lina token proxy address
    LnLinearStakingStorage public stakingStorage;
    uint256 public mEndBlock;
    address public mOldStaking;
    uint256 public mOldAmount;
    uint256 public mWidthdrawRewardFromOldStaking;

    uint256 public claimRewardLockTime = 1620806400; // 2021-5-12

    address public mTargetAddress;
    uint256 public mTransLockTime;

    mapping(address => uint256) public mOldReward;

    constructor(
        address _admin,
        address _linaToken,
        address _storage,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public LnAdmin(_admin) LnRewardCalculator(_rewardPerBlock, _startBlock) {
        linaToken = IERC20(_linaToken);
        stakingStorage = LnLinearStakingStorage(_storage);
        mEndBlock = _endBlock;
    }

    function setLinaToken(address _linaToken) external onlyAdmin {
        linaToken = IERC20(_linaToken);
    }

    function setPaused(bool _paused) external onlyAdmin {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    //////////////////////////////////////////////////////
    event Staking(address indexed who, uint256 value, uint256 staketime);
    event CancelStaking(address indexed who, uint256 value);
    event Claim(address indexed who, uint256 rewardval, uint256 totalStaking);
    event TransLock(address target, uint256 time);

    uint256 public accountStakingListLimit = 50;
    uint256 public minStakingAmount = 1e18; // 1 token
    uint256 public constant PRECISION_UINT = 1e23;

    function setStakingListLimit(uint256 _limit) external onlyAdmin {
        accountStakingListLimit = _limit;
    }

    function setMinStakingAmount(uint256 _minStakingAmount) external onlyAdmin {
        minStakingAmount = _minStakingAmount;
    }

    function stakingBalanceOf(address account)
        external
        override
        view
        returns (uint256)
    {
        uint256 stakingBalance = super.amountOf(account).add(
            stakingStorage.stakingBalanceOf(account)
        );
        return stakingBalance;
    }

    function getStakesdataLength(address account)
        external
        view
        returns (uint256)
    {
        return stakingStorage.getStakesdataLength(account);
    }

    //--------------------------------------------------------

    function migrationsOldStaking(
        address contractAddr,
        uint256 amount,
        uint256 blockNb
    ) public onlyAdmin {
        super._deposit(blockNb, contractAddr, amount);
        mOldStaking = contractAddr;
        mOldAmount = amount;
    }

    function staking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        stakingStorage.requireInStakingPeriod();

        require(amount >= minStakingAmount, "Staking amount too small.");
        //require(stakingStorage.getStakesdataLength(msg.sender) < accountStakingListLimit, "Staking list out of limit.");

        linaToken.transferFrom(msg.sender, address(this), amount);

        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }
        super._deposit(blockNb, msg.sender, amount);

        emit Staking(msg.sender, amount, block.timestamp);

        return true;
    }

    function _widthdrawFromOldStaking(address _addr, uint256 amount) internal {
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 oldStakingAmount = super.amountOf(mOldStaking);
        super._withdraw(blockNb, mOldStaking, amount);
        // sub already withraw reward, then cal portion
        uint256 reward = super
            .rewardOf(mOldStaking)
            .sub(
            mWidthdrawRewardFromOldStaking,
            "_widthdrawFromOldStaking reward sub overflow"
        )
            .mul(amount)
            .mul(1e20)
            .div(oldStakingAmount)
            .div(1e20);
        mWidthdrawRewardFromOldStaking = mWidthdrawRewardFromOldStaking.add(
            reward
        );
        mOldReward[_addr] = mOldReward[_addr].add(reward);
    }

    function _cancelStaking(address user, uint256 amount) internal {
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 returnAmount = amount;
        uint256 newAmount = super.amountOf(user);
        if (newAmount >= amount) {
            super._withdraw(blockNb, user, amount);
            amount = 0;
        } else {
            if (newAmount > 0) {
                super._withdraw(blockNb, user, newAmount);
                amount = amount.sub(
                    newAmount,
                    "_cancelStaking amount sub overflow"
                );
            }

            for (
                uint256 i = stakingStorage.getStakesdataLength(user);
                i >= 1;
                i--
            ) {
                (uint256 stakingAmount, uint256 staketime) = stakingStorage
                    .getStakesDataByIndex(user, i - 1);
                if (amount >= stakingAmount) {
                    amount = amount.sub(
                        stakingAmount,
                        "_cancelStaking amount sub overflow"
                    );

                    stakingStorage.PopStakesData(user);
                    stakingStorage.SubWeeksTotal(staketime, stakingAmount);
                    _widthdrawFromOldStaking(user, stakingAmount);
                } else {
                    stakingStorage.StakingDataSub(user, i - 1, amount);
                    stakingStorage.SubWeeksTotal(staketime, amount);
                    _widthdrawFromOldStaking(user, amount);

                    amount = 0;
                }
                if (amount == 0) break;
            }
        }

        // cancel as many as possible, not fail, that waste gas
        //require(amount == 0, "Cancel amount too big then staked.");

        linaToken.transfer(msg.sender, returnAmount.sub(amount));
    }

    function cancelStaking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        //stakingStorage.requireInStakingPeriod();

        require(amount > 0, "Invalid amount.");

        _cancelStaking(msg.sender, amount);

        emit CancelStaking(msg.sender, amount);

        return true;
    }

    function getTotalReward(uint256 blockNb, address _user)
        public
        view
        returns (uint256 total)
    {
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        // 这里奖励分成了三部分
        // 1,已经从旧奖池中cancel了的
        // 2,还在旧奖池中的
        // 3，在新奖池中的
        total = mOldReward[_user];
        uint256 iMyOldStaking = 0;
        for (
            uint256 i = 0;
            i < stakingStorage.getStakesdataLength(_user);
            i++
        ) {
            (uint256 stakingAmount, ) = stakingStorage.getStakesDataByIndex(
                _user,
                i
            );
            iMyOldStaking = iMyOldStaking.add(stakingAmount);
        }
        if (iMyOldStaking > 0) {
            uint256 oldStakingAmount = super.amountOf(mOldStaking);
            uint256 iReward2 = super
                ._calcReward(blockNb, mOldStaking)
                .sub(
                mWidthdrawRewardFromOldStaking,
                "getTotalReward iReward2 sub overflow"
            )
                .mul(iMyOldStaking)
                .div(oldStakingAmount);
            total = total.add(iReward2);
        }

        uint256 reward3 = super._calcReward(blockNb, _user);
        total = total.add(reward3);
    }

    // claim reward
    // Note: 需要提前提前把奖励token转进来
    function claim() public override whenNotPaused returns (bool) {
        //stakingStorage.requireStakingEnd();
        require(
            block.timestamp > claimRewardLockTime,
            "Not time to claim reward"
        );

        uint256 iMyOldStaking = stakingStorage.stakingBalanceOf(msg.sender);
        uint256 iAmount = super.amountOf(msg.sender);
        _cancelStaking(msg.sender, iMyOldStaking.add(iAmount));

        uint256 iReward = getTotalReward(mEndBlock, msg.sender);

        _claim(msg.sender);
        mOldReward[msg.sender] = 0;
        linaToken.transfer(msg.sender, iReward);

        emit Claim(msg.sender, iReward, iMyOldStaking.add(iAmount));
        return true;
    }

    function setRewardLockTime(uint256 newtime) public onlyAdmin {
        claimRewardLockTime = newtime;
    }

    function calcReward(uint256 curBlock, address _user)
        public
        view
        returns (uint256)
    {
        return _calcReward(curBlock, _user);
    }

    function setTransLock(address target, uint256 locktime) public onlyAdmin {
        require(
            locktime >= now + 2 days,
            "locktime need larger than cur time 2 days"
        );
        mTargetAddress = target;
        mTransLockTime = locktime;

        emit TransLock(mTargetAddress, mTransLockTime);
    }

    function transTokens(uint256 amount) public onlyAdmin {
        require(mTransLockTime > 0, "mTransLockTime not set");
        require(now > mTransLockTime, "Pls wait to unlock time");
        linaToken.transfer(mTargetAddress, amount);
    }
}

contract HelperPushStakingData is LnAdmin {
    constructor(address _admin) public LnAdmin(_admin) {}

    function pushStakingData(
        address _storage,
        address[] calldata account,
        uint256[] calldata amount,
        uint256[] calldata staketime
    ) external {
        require(account.length > 0, "array length zero");
        require(account.length == amount.length, "array length not eq");
        require(account.length == staketime.length, "array length not eq");

        LnLinearStakingStorage stakingStorage = LnLinearStakingStorage(
            _storage
        );
        for (uint256 i = 0; i < account.length; i++) {
            stakingStorage.PushStakingData(account[i], amount[i], staketime[i]);
            stakingStorage.AddWeeksTotal(staketime[i], amount[i]);
        }
    }

    //unstaking.
}

contract MultiSigForTransferFunds {
    mapping(address => uint256) public mAdmins;
    uint256 public mConfirmNumb;
    uint256 public mProposalNumb;
    uint256 public mAmount;
    LnSimpleStaking public mStaking;
    address[] public mAdminArr;
    uint256 public mTransLockTime;

    constructor(
        address[] memory _addr,
        uint256 iConfirmNumb,
        LnSimpleStaking _staking
    ) public {
        for (uint256 i = 0; i < _addr.length; ++i) {
            mAdmins[_addr[i]] = 1;
        }
        mConfirmNumb = iConfirmNumb;
        mProposalNumb = 0;
        mStaking = _staking;
        mAdminArr = _addr;
    }

    function becomeAdmin(address target) external {
        LnAdmin(target).becomeAdmin();
    }

    function setTransLock(
        address target,
        uint256 locktime,
        uint256 amount
    ) public {
        require(mAdmins[msg.sender] == 1, "not in admin list or set state");
        _reset();
        mStaking.setTransLock(target, locktime);
        mAmount = amount;
        mProposalNumb = 1;
        mAdmins[msg.sender] = 2; //

        mTransLockTime = locktime;
    }

    // call this when the locktime expired
    function confirmTransfer() public {
        require(mAdmins[msg.sender] == 1, "not in admin list or set state");
        mProposalNumb = mProposalNumb + 1;
        mAdmins[msg.sender] = 2;
    }

    function doTransfer() public {
        require(mTransLockTime > 0, "mTransLockTime not set");
        require(now > mTransLockTime, "Pls wait to unlock time");
        require(mProposalNumb >= mConfirmNumb, "need more confirm");

        _reset();
        mStaking.transTokens(mAmount);
    }

    function _reset() internal {
        mProposalNumb = 0;
        mTransLockTime = 0;
        // reset
        for (uint256 i = 0; i < mAdminArr.length; ++i) {
            mAdmins[mAdminArr[i]] = 1;
        }
    }
}

/////////////////////////////////////
contract LnSimpleStakingExtension is
    LnAdmin,
    Pausable,
    ILinearStaking,
    LnRewardCalculator
{
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;

    IERC20 public linaToken; // lina token proxy address
    uint256 public mEndBlock;

    //Handle old pool staking
    address public mOldStaking;
    uint256 public mOldAmount;
    uint256 public mWidthdrawRewardFromOldStaking;

    uint256 public claimRewardLockTime = 1620806400; // 2021-5-12

    address public mTargetAddress;
    uint256 public mTransLockTime;

    mapping(address => uint256) public mOldReward;
    LnSimpleStaking public mOldSimpleStaking;

    constructor(
        address _admin,
        address _linaToken,
        // address _storage,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        address _mOldSimpleStaking
    ) public LnAdmin(_admin) LnRewardCalculator(_rewardPerBlock, _startBlock) {
        linaToken = IERC20(_linaToken);
        // stakingStorage = LnLinearStakingStorage(_storage);
        mEndBlock = _endBlock;

        if (_mOldSimpleStaking != address(0)) {
            mOldSimpleStaking = LnSimpleStaking(_mOldSimpleStaking);
        }
    }

    function setLinaToken(address _linaToken) external onlyAdmin {
        linaToken = IERC20(_linaToken);
    }

    function setPaused(bool _paused) external onlyAdmin {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    //////////////////////////////////////////////////////
    event Staking(address indexed who, uint256 value, uint256 staketime);
    event CancelStaking(address indexed who, uint256 value);
    event Claim(address indexed who, uint256 rewardval, uint256 totalStaking);
    event TransLock(address target, uint256 time);

    uint256 public accountStakingListLimit = 50;
    uint256 public minStakingAmount = 1e18; // 1 token
    uint256 public constant PRECISION_UINT = 1e23;

    function setStakingListLimit(uint256 _limit) external onlyAdmin {
        accountStakingListLimit = _limit;
    }

    function setMinStakingAmount(uint256 _minStakingAmount) external onlyAdmin {
        minStakingAmount = _minStakingAmount;
    }

    function stakingBalanceOf(address account)
        external
        override
        view
        returns (uint256)
    {
        uint256 stakingBalance = super.amountOf(account).add(
            mOldSimpleStaking.stakingBalanceOf(account)
        );
        return stakingBalance;
    }

    // function getStakesdataLength(address account)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return stakingStorage.getStakesdataLength(account);
    // }

    //--------------------------------------------------------

    function migrationsOldStaking(
        address contractAddr,
        uint256 amount,
        uint256 blockNb
    ) public onlyAdmin {
        super._deposit(blockNb, contractAddr, amount);
        mOldStaking = contractAddr;
        mOldAmount = amount;
    }

    function migrateData(
        address[] calldata users,
        bytes32[] calldata actions,
        uint256[] calldata blockIntake,
        uint256[] calldata amount
    ) public onlyAdmin {
        require(
            users.length == amount.length,
            "parameter address length not eq"
        );
        require(
            actions.length == amount.length,
            "parameter address length not eq"
        );
        require(
            blockIntake.length == amount.length,
            "parameter address length not eq"
        );

        for (uint256 i = 0; i < users.length; i++) {
            if (actions[i] == "deposit") {
                _deposit(blockIntake[i], users[i], amount[i]);
            } else if (actions[i] == "withdraw") {
                _withdraw(blockIntake[i], users[i], amount[i]);
            }
        }
    }

    function staking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        // stakingStorage.requireInStakingPeriod();

        require(amount >= minStakingAmount, "Staking amount too small.");
        //require(stakingStorage.getStakesdataLength(msg.sender) < accountStakingListLimit, "Staking list out of limit.");

        linaToken.transferFrom(msg.sender, address(this), amount);

        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }
        super._deposit(blockNb, msg.sender, amount);

        emit Staking(msg.sender, amount, block.timestamp);

        return true;
    }

    function _widthdrawFromOldStaking(address _addr, uint256 amount) internal {
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 oldStakingAmount = super.amountOf(mOldStaking);
        super._withdraw(blockNb, mOldStaking, amount);
        // sub already withraw reward, then cal portion
        uint256 reward = super
            .rewardOf(mOldStaking)
            .sub(
            mWidthdrawRewardFromOldStaking,
            "_widthdrawFromOldStaking reward sub overflow"
        )
            .mul(amount)
            .mul(1e20)
            .div(oldStakingAmount)
            .div(1e20);
        mWidthdrawRewardFromOldStaking = mWidthdrawRewardFromOldStaking.add(
            reward
        );
        mOldReward[_addr] = mOldReward[_addr].add(reward);
    }

    function _cancelStaking(address user, uint256 amount) internal {
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 returnAmount = amount;
        uint256 newAmount = super.amountOf(user);
        if (newAmount >= amount) {
            super._withdraw(blockNb, user, amount);
            amount = 0;
        } else {
            if (newAmount > 0) {
                super._withdraw(blockNb, user, newAmount);
                amount = amount.sub(
                    newAmount,
                    "_cancelStaking amount sub overflow"
                );
            }

            uint256 oldStakingAmount = mOldSimpleStaking.stakingBalanceOf(user);

            if (amount >= oldStakingAmount) {
                amount = amount.sub(
                    oldStakingAmount,
                    "_cancelStaking amount sub overflow"
                );
                mOldSimpleStaking.cancelStaking(oldStakingAmount);
                _widthdrawFromOldStaking(user, oldStakingAmount);
            }
        }

        // cancel as many as possible, not fail, that waste gas
        //require(amount == 0, "Cancel amount too big then staked.");

        linaToken.transfer(msg.sender, returnAmount.sub(amount));
    }

    function cancelStaking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        //stakingStorage.requireInStakingPeriod();

        require(amount > 0, "Invalid amount.");

        _cancelStaking(msg.sender, amount);

        emit CancelStaking(msg.sender, amount);

        return true;
    }

    function getTotalReward(uint256 blockNb, address _user)
        public
        view
        returns (uint256 total)
    {
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        // Cater 2 parts rewards
        // 1. old rewards in simpleStaking
        // 2. new rewards in this pool
        // 3. new rewards in simpleStaking
        total = mOldSimpleStaking.getTotalReward(blockNb, _user);

        // In this part, we need to include old the old staking
        uint256 newReward = super._calcReward(blockNb, _user);
        total = total.add(newReward);

        // 3.
        uint256 oldStakeNewReward = _calcOldStakingNewReward(blockNb, _user);
        total = total.add(oldStakeNewReward);
    }

    // To calcuate the old staking in the new period rewards
    function _calcOldStakingNewReward(uint256 curBlock, address _user)
        internal
        view
        returns (uint256)
    {
        uint256 oldStaking = mOldSimpleStaking.stakingBalanceOf(_user);
        PoolInfo storage pool = mPoolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.amount;
        if (curBlock > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = curBlock.sub(
                pool.lastRewardBlock,
                "cr curBlock sub overflow"
            );
            uint256 curReward = multiplier.mul(rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(
                curReward.mul(1e20).div(lpSupply)
            );
        }
        uint256 newReward = oldStaking.mul(accRewardPerShare).div(1e20).sub(
            user.rewardDebt,
            "cr newReward sub overflow"
        );
        return newReward.add(user.reward);
    }

    // claim reward
    // Note: 需要提前提前把奖励token转进来
    function claim() public override whenNotPaused returns (bool) {
        //stakingStorage.requireStakingEnd();
        require(
            block.timestamp > claimRewardLockTime,
            "Not time to claim reward"
        );

        uint256 iMyOldStaking = mOldSimpleStaking.stakingBalanceOf(msg.sender);
        uint256 iAmount = super.amountOf(msg.sender);
        _cancelStaking(msg.sender, iMyOldStaking.add(iAmount));

        uint256 iReward = getTotalReward(mEndBlock, msg.sender);

        _claim(msg.sender);
        mOldReward[msg.sender] = 0;
        linaToken.transfer(msg.sender, iReward);

        emit Claim(msg.sender, iReward, iMyOldStaking.add(iAmount));
        return true;
    }

    function setRewardLockTime(uint256 newtime) public onlyAdmin {
        claimRewardLockTime = newtime;
    }

    function calcReward(uint256 curBlock, address _user)
        public
        view
        returns (uint256)
    {
        return _calcReward(curBlock, _user);
    }

    function setTransLock(address target, uint256 locktime) public onlyAdmin {
        require(
            locktime >= now + 2 days,
            "locktime need larger than cur time 2 days"
        );
        mTargetAddress = target;
        mTransLockTime = locktime;

        emit TransLock(mTargetAddress, mTransLockTime);
    }

    function transTokens(uint256 amount) public onlyAdmin {
        require(mTransLockTime > 0, "mTransLockTime not set");
        require(now > mTransLockTime, "Pls wait to unlock time");
        linaToken.transfer(mTargetAddress, amount);
    }
}



///////////

contract LnSimpleStakingNew is
    LnAdmin,
    Pausable,
    ILinearStaking,
    LnRewardCalculator
{
    using SafeMath for uint256;
    using SafeDecimalMath for uint256;

    IERC20 public linaToken; // lina token proxy address
    LnSimpleStaking public simpleStaking;
    uint256 public mEndBlock;
    address public mOldStaking;
    uint256 public mOldAmount;
    uint256 public mWidthdrawRewardFromOldStaking;

    uint256 public claimRewardLockTime = 1620806400; // 2021-5-12

    address public mTargetAddress;
    uint256 public mTransLockTime;

    mapping(address => uint256) public mOldReward;
    mapping(address => uint256) public mOldStake;
    mapping(address => bool)    public userSync;

    constructor(
        address _admin,
        address _linaToken,
        address _staking,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public LnAdmin(_admin) LnRewardCalculator(_rewardPerBlock, _startBlock) {
        linaToken = IERC20(_linaToken);
        simpleStaking = LnSimpleStaking(_staking);
        mEndBlock = _endBlock;
    }

    function setLinaToken(address _linaToken) external onlyAdmin {
        linaToken = IERC20(_linaToken);
    }

    function setPaused(bool _paused) external onlyAdmin {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    //////////////////////////////////////////////////////
    event Staking(address indexed who, uint256 value, uint256 staketime);
    event CancelStaking(address indexed who, uint256 value);
    event CancelStakingV2(address indexed who, uint256 value);
    event Claim(address indexed who, uint256 rewardval, uint256 totalStaking);
    event TransLock(address target, uint256 time);

    uint256 public accountStakingListLimit = 50;
    uint256 public minStakingAmount = 1e18; // 1 token
    uint256 public constant PRECISION_UINT = 1e23;

    function setStakingListLimit(uint256 _limit) external onlyAdmin {
        accountStakingListLimit = _limit;
    }

    function setMinStakingAmount(uint256 _minStakingAmount) external onlyAdmin {
        minStakingAmount = _minStakingAmount;
    }

    function setEndBlock(uint256 _endBlock) external onlyAdmin {
        if (mEndBlock < _endBlock){
            mEndBlock = _endBlock;
        }
    }

    function stakingBalanceOf(address account)
        external
        override
        view
        returns (uint256)
    {
        uint256 stakingBalance = 0;
        if (userSync[msg.sender]){
            stakingBalance = super.amountOf(account).add(mOldStake[account]);
        } else {
            stakingBalance = super.amountOf(account).add(simpleStaking.stakingBalanceOf(account));
        }
        
        return stakingBalance;
    }

    // function getStakesdataLength(address account)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return simpleStaking.getStakesdataLength(account);
    // }

    //--------------------------------------------------------

    function migrationsOldStaking(
        address contractAddr,
        uint256 amount,
        uint256 blockNb
    ) public onlyAdmin {
        super._deposit(blockNb, contractAddr, amount);
        mOldStaking = contractAddr;
        mOldAmount = amount;
    }

    //for 之前有bug的合约把stake in入去的数据migrate到本合约，
    //migrate data后必须将之前合约到lina转到本合约
    function migrateOldStakInData(
        address[] memory users,
        uint256[] memory blockIntake,
        uint256[] memory amount
    ) public onlyAdmin {
        require(
            users.length == amount.length,
            "parameter address length not eq"
        );
        require(
            blockIntake.length == amount.length,
            "parameter address length not eq"
        );

        for (uint256 i = 0; i < users.length; i++) {
            super._deposit(blockIntake[i], users[i], amount[i]);
        }
    }

    function migrateOldStakOutData(
        address[] memory users,
        uint256[] memory blockIntake,
        uint256[] memory amount
    ) public onlyAdmin {
        require(
            users.length == amount.length,
            "parameter address length not eq"
        );
        require(
            blockIntake.length == amount.length,
            "parameter address length not eq"
        );

        for (uint256 i = 0; i < users.length; i++) {
            super._withdraw(blockIntake[i], users[i], amount[i]);
        }
    }

    function migrateData(
        address[] calldata users,
        uint256[] calldata actions,
        uint256[] calldata blockIntake,
        uint256[] calldata amount
    ) public onlyAdmin {
        require(
            users.length == amount.length,
            "parameter address length not eq"
        );
        require(
            actions.length == amount.length,
            "parameter address length not eq"
        );
        require(
            blockIntake.length == amount.length,
            "parameter address length not eq"
        );

        for (uint256 i = 0; i < users.length; i++) {
            if (actions[i] == 1) {
                _deposit(blockIntake[i], users[i], amount[i]);
            } else if (actions[i] == 2) {
                _withdraw(blockIntake[i], users[i], amount[i]);
            }
        }
    }

    function staking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        //stakingStorage.requireInStakingPeriod();

        require(amount >= minStakingAmount, "Staking amount too small.");
        //require(stakingStorage.getStakesdataLength(msg.sender) < accountStakingListLimit, "Staking list out of limit.");
        if(!userSync[msg.sender] ){
            mOldStake[msg.sender] = simpleStaking.stakingBalanceOf(msg.sender);
            userSync[msg.sender] = true;
        }
        linaToken.transferFrom(msg.sender, address(this), amount);

        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }
        super._deposit(blockNb, msg.sender, amount);

        emit Staking(msg.sender, amount, block.timestamp);

        return true;
    }

    function _widthdrawFromOldStaking(address _addr, uint256 amount) internal {
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }
        uint256 oldStakingAmount = super.amountOf(mOldStaking);
        super._withdraw(blockNb, mOldStaking, amount);
        // sub already withraw reward, then cal portion
        uint256 reward = super
            .rewardOf(mOldStaking)
            .sub(
            mWidthdrawRewardFromOldStaking,
            "_widthdrawFromOldStaking reward sub overflow"
        )
            .mul(amount)
            .mul(1e20)
            .div(oldStakingAmount)
            .div(1e20);
        mWidthdrawRewardFromOldStaking = mWidthdrawRewardFromOldStaking.add(
            reward
        );
        mOldReward[_addr] = mOldReward[_addr].add(reward);
        mOldStake[_addr] = mOldStake[_addr].sub(amount, "_widthdrawFromOldStaking staking sub overflow");
    }


    function _cancelStaking(address user, uint256 amount) internal returns(bool){
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 unStakingFromNew = 0;
        uint256 newAmount = super.amountOf(user);
        if (newAmount >= amount) {
            super._withdraw(blockNb, user, amount);
            amount = 0;
            unStakingFromNew = amount;
        } else {
            if (newAmount > 0) {
                super._withdraw(blockNb, user, newAmount);
                amount = amount.sub(
                    newAmount,
                    "_cancelStaking amount sub overflow"
                );
                unStakingFromNew = newAmount;
            }

        }
        if ( unStakingFromNew > 0 ){
           linaToken.transfer(msg.sender, unStakingFromNew);
        }
        
        return true;
    }

    function _cancelStakingV2(address user, uint256 amount) internal returns(uint256){
        uint256 blockNb = block.number;
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        uint256 unStakingFromNew = 0;
        uint256 unStakingFromOld = 0;
        uint256 newAmount = super.amountOf(user);
        if (newAmount >= amount) {
            unStakingFromNew = unStakingFromNew.add(amount);
            super._withdraw(blockNb, user, amount);
            amount = 0;
        } else {
            if (newAmount > 0) {
                unStakingFromNew = unStakingFromNew.add(newAmount);
                super._withdraw(blockNb, user, newAmount);
                amount = amount.sub(
                    newAmount,
                    "_cancelStaking amount sub overflow"
                );
            }
            //以下处理只在本合约进行计数，没有在旧合约发生cancelStaking动作，前端必须多调用一次旧合约进行实际cancelStaking
            uint256 oldAmount = 0;

            if ( userSync[user]){
                oldAmount = mOldStake[user];
            } else {
                oldAmount = simpleStaking.stakingBalanceOf(user);
            }
            if (oldAmount > 0 && amount > 0){
                if ( oldAmount> amount) {
                    unStakingFromOld = unStakingFromOld.add(amount);
                    _widthdrawFromOldStaking(user, amount);
                    amount = amount.sub(
                        amount,
                        "_cancelStaking amount sub overflow"
                    );
                } else {
                    unStakingFromOld = unStakingFromOld.add(oldAmount);
                     _widthdrawFromOldStaking(user, oldAmount);
                    amount = amount.sub(
                        oldAmount,
                        "_cancelStaking amount sub overflow"
                    );
                }

            }
        }

        linaToken.transfer(msg.sender, unStakingFromNew);
        return unStakingFromOld;
    }

    function cancelStaking(uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {

        require(amount > 0, "Invalid amount.");

        if(!userSync[msg.sender]){
            mOldStake[msg.sender] = simpleStaking.stakingBalanceOf(msg.sender);
            userSync[msg.sender] = true;
        }

         _cancelStaking(msg.sender, amount);

        emit CancelStaking(msg.sender, amount);

        return true;
    }

    //返回需要在旧的simpleStaking由前端调用cancelStaking的数量
    function cancelStakingV2(uint256 amount)
        public
        whenNotPaused
        returns (uint256)
    {

        require(amount > 0, "Invalid amount.");

        if(!userSync[msg.sender]){
            mOldStake[msg.sender] = simpleStaking.stakingBalanceOf(msg.sender);
            userSync[msg.sender] = true;
        }

        uint256 unStakingFromOld = 0;
        unStakingFromOld = _cancelStakingV2(msg.sender, amount);

        emit CancelStakingV2(msg.sender, amount);

        return unStakingFromOld;
    }


    function getTotalReward(uint256 blockNb, address _user)
        public
        view
        returns (uint256 total)
    {
        if (blockNb > mEndBlock) {
            blockNb = mEndBlock;
        }

        // 这里奖励分成了三部分
        // 1,已经从旧奖池中cancel了的
        // 2,还在旧奖池中的
        // 3，在新奖池中的

        //第一部分

        uint256 reward1 = simpleStaking.getTotalReward(blockNb, _user);

        //第二部分
        total = mOldReward[_user];

        uint256 iMyOldStaking = 0;

        if ( userSync[_user]){
            iMyOldStaking = mOldStake[_user];
        } else {
            iMyOldStaking = simpleStaking.stakingBalanceOf(_user);
        }

        if (iMyOldStaking > 0) {
            uint256 oldStakingAmount = super.amountOf(mOldStaking);
            uint256 iReward2 = super._calcReward(blockNb, mOldStaking)
                .sub(
                mWidthdrawRewardFromOldStaking,
                "getTotalReward iReward2 sub overflow"
            )
                .mul(iMyOldStaking)
                .div(oldStakingAmount);
            total = total.add(iReward2);
        }

        //第三部分
        uint256 reward3 = super._calcReward(blockNb, _user);
        total = total.add(reward3).add(reward1);
    }

    // claim reward
    // Note: 需要提前提前把奖励token转进来
    function claim() public override whenNotPaused returns (bool) {
        //stakingStorage.requireStakingEnd();
        require(
            block.timestamp > claimRewardLockTime,
            "Not time to claim reward"
        );

        uint256 iMyOldStaking = 0;
        if ( userSync[msg.sender]){
            iMyOldStaking = mOldStake[msg.sender];
        } else {
            iMyOldStaking = simpleStaking.stakingBalanceOf(msg.sender);
        }
        uint256 iAmount = super.amountOf(msg.sender);
        _cancelStaking(msg.sender, iMyOldStaking.add(iAmount));

        uint256 iReward = getTotalReward(mEndBlock, msg.sender);

        _claim(msg.sender);
        mOldReward[msg.sender] = 0;
        linaToken.transfer(msg.sender, iReward);

        emit Claim(msg.sender, iReward, iMyOldStaking.add(iAmount));
        return true;
    }

    function setRewardLockTime(uint256 newtime) public onlyAdmin {
        claimRewardLockTime = newtime;
    }

    function calcReward(uint256 curBlock, address _user)
        public
        view
        returns (uint256)
    {
        return _calcReward(curBlock, _user);
    }

    function setTransLock(address target, uint256 locktime) public onlyAdmin {
        require(
            locktime >= now + 2 days,
            "locktime need larger than cur time 2 days"
        );
        mTargetAddress = target;
        mTransLockTime = locktime;

        emit TransLock(mTargetAddress, mTransLockTime);
    }

    function transTokens(uint256 amount) public onlyAdmin {
        require(mTransLockTime > 0, "mTransLockTime not set");
        require(now > mTransLockTime, "Pls wait to unlock time");
        linaToken.transfer(mTargetAddress, amount);
    }
}
