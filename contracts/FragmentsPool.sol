//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "./interfaces/IGoddessFragments.sol";
import "./RewardsPool.sol";

contract FragmentsPool is RewardsPool {
    IGoddessFragments public goddessFragments;
    uint256 public fragmentsPerWeek; // per max cap
    uint256 public fragmentsPerTokenStored;
    mapping(address => uint256) public fragments;
    mapping(address => uint256) public userFragmentsPerTokenPaid;
    uint256 public fragmentsLastUpdateTime;

    constructor(
        uint256 _tokenCapAmount,
        IERC20 _stakeToken,
        IERC20 _goddessToken,
        IUniswapRouter _uniswapRouter,
        uint256 _starttime,
        uint256 _duration,
        IGoddessFragments _goddessFragments
    )
        public
        RewardsPool(
            _tokenCapAmount,
            _stakeToken,
            _goddessToken,
            _uniswapRouter,
            _starttime,
            _duration
        )
    {
        goddessFragments = _goddessFragments;
    }

    modifier updateFragments(address account) {
        fragmentsPerTokenStored = fragmentsPerToken();
        fragmentsLastUpdateTime = block.timestamp;
        if (account != address(0)) {
            fragments[account] = fragmentsEarned(account);
            userFragmentsPerTokenPaid[account] = fragmentsPerTokenStored;
        }
        _;
    }

    function balanceFarmFragments(address account) public view returns (uint256) {
        return Math.min(balanceOf(account), tokenCapAmount);
    }

    function fragmentsPerToken() public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        return
            fragmentsPerTokenStored.add(
                fragmentsPerWeek
                    .mul(blockTime.sub(fragmentsLastUpdateTime))
                    .mul(1e18)
                    .div(604800)
                    .div(tokenCapAmount)
            );
    }

    function fragmentsEarned(address account) public view returns (uint256) {
        return
            fragments[account].add(
                balanceFarmFragments(account).mul(
                    fragmentsPerToken().sub(userFragmentsPerTokenPaid[account])
                )
                // .div(1e18)
            );
    }

    function stake(uint256 amount, address referrer) public updateFragments(msg.sender) {
        super.stake(amount, referrer);
    }

    function withdraw(uint256 amount) public updateFragments(msg.sender) {
        super.withdraw(amount);
    }

    function getReward() public updateFragments(msg.sender) {
        super.getReward();
        uint256 reward = fragmentsEarned(msg.sender);
        if (reward > 0) {
            goddessFragments.collectedFragments(msg.sender, reward);
            fragments[msg.sender] = 0;
        }
    }

    function setFragmentsPerWeek(uint256 _fragmentsPerWeek)
        public
        updateFragments(address(0))
        onlyAdmin
    {
        fragmentsPerWeek = _fragmentsPerWeek;
    }

    function setGoddessFragments(address _goddessFragments) public onlyAdmin {
        goddessFragments = IGoddessFragments(_goddessFragments);
    }

    function setTokenCapAmount(uint256 _tokenCapAmount)
        public
        onlyAdmin
        updateFragments(address(0))
    {
        tokenCapAmount = _tokenCapAmount;
    }
}
