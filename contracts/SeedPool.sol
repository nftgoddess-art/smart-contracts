//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./interfaces/IReferral.sol";
import "./utils/Withdrawable.sol";
import "./utils/LPTokenWrapper.sol";

contract SeedPool is LPTokenWrapper, Withdrawable {
    IERC20 public goddessToken;
    uint256 public tokenCapAmount;
    uint256 public starttime;
    uint256 public duration;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    IReferral public referral;

    // variables to keep track of totalSupply and balances (after accounting for multiplier)
    uint256 internal totalStakingBalance;
    mapping(address => uint256) internal stakeBalance;
    uint256 internal constant PRECISION = 1e18;
    uint256 public constant REFERRAL_COMMISSION_PERCENT = 1;
    uint256 private constant ONE_WEEK = 604800;

    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);

    modifier checkStart() {
        require(block.timestamp >= starttime, "not start");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        uint256 _tokenCapAmount,
        IERC20 _stakeToken,
        IERC20 _goddessToken,
        uint256 _starttime,
        uint256 _duration
    ) public LPTokenWrapper(_stakeToken) Withdrawable(msg.sender) {
        tokenCapAmount = _tokenCapAmount;
        goddessToken = _goddessToken;
        starttime = _starttime;
        duration = _duration;
        Withdrawable.setBlackList(address(_goddessToken));
        Withdrawable.setBlackList(address(_stakeToken));
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStakingBalance == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(
                    totalStakingBalance
                )
            );
    }

    function earned(address account) public view returns (uint256) {
        return totalEarned(account).mul(100 - REFERRAL_COMMISSION_PERCENT).div(100);
    }

    function totalEarned(address account) internal view returns (uint256) {
        return
            stakeBalance[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount, address referrer) public updateReward(msg.sender) checkStart {
        checkCap(amount, msg.sender);
        _stake(amount, referrer);
    }

    function _stake(uint256 amount, address referrer) internal {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);

        // update goddess balance and supply
        updateStakeBalanceAndSupply(msg.sender);

        // transfer token last, to follow CEI pattern
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        // update referrer
        if (address(referral) != address(0) && referrer != address(0)) {
            referral.setReferrer(msg.sender, referrer);
        }
    }

    function checkCap(uint256 amount, address user) private view {
        // check user cap
        require(
            balanceOf(user).add(amount) <= tokenCapAmount ||
                block.timestamp >= starttime.add(ONE_WEEK),
            "token cap exceeded"
        );
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);

        // update goddess balance and supply
        updateStakeBalanceAndSupply(msg.sender);

        stakeToken.safeTransfer(msg.sender, amount);
        getReward();
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkStart {
        uint256 reward = totalEarned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            uint256 actualRewards = reward.mul(100 - REFERRAL_COMMISSION_PERCENT).div(100); // 99%
            uint256 commission = reward.sub(actualRewards); // 1%
            goddessToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
            address referrer = address(0);
            if (address(referral) != address(0)) {
                referrer = referral.getReferrer(msg.sender);
            }
            if (referrer != address(0)) {
                // send commission to referrer
                goddessToken.safeTransfer(referrer, commission);
            } else {
                // or burn
                ERC20Burnable burnableGoddessToken = ERC20Burnable(address(goddessToken));
                burnableGoddessToken.burn(commission);
            }
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyAdmin updateReward(address(0)) {
        rewardRate = reward.div(duration);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(duration);
        emit RewardAdded(reward);
    }

    function updateStakeBalanceAndSupply(address user) private {
        // subtract existing balance from goddessSupply
        totalStakingBalance = totalStakingBalance.sub(stakeBalance[user]);
        // calculate and update new goddess balance (user's balance has been updated by parent method)
        uint256 newStakeBalance = balanceOf(user);
        stakeBalance[user] = newStakeBalance;
        // update totalStakingBalance
        totalStakingBalance = totalStakingBalance.add(newStakeBalance);
    }

    function setReferral(IReferral _referral) external onlyAdmin {
        referral = _referral;
    }
}
