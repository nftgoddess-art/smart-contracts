//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./interfaces/IReferral.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IUniswapRouter.sol";
import "./utils/Withdrawable.sol";
import "./utils/LPTokenWrapper.sol";
import "./SeedPool.sol";

contract RewardsPool is SeedPool {
    address public governance;
    IUniswapRouter public uniswapRouter;
    address public stablecoin;

    // blessing variables
    // variables to keep track of totalSupply and balances (after accounting for multiplier)
    uint256 public lastBlessingTime; // timestamp of lastBlessingTime
    mapping(address => uint256) public numBlessing; // each blessing = 5% increase in stake amt
    mapping(address => uint256) public nextBlessingTime; // timestamp for which user is eligible to purchase another blessing
    uint256 public globalBlessPrice = 10**18;
    uint256 public blessThreshold = 10;
    uint256 public blessScaleFactor = 20;
    uint256 public scaleFactor = 320;

    constructor(
        uint256 _tokenCapAmount,
        IERC20 _stakeToken,
        IERC20 _goddessToken,
        IUniswapRouter _uniswapRouter,
        uint256 _starttime,
        uint256 _duration
    ) public SeedPool(_tokenCapAmount, _stakeToken, _goddessToken, _starttime, _duration) {
        uniswapRouter = _uniswapRouter;
        goddessToken.safeApprove(address(_uniswapRouter), 2**256 - 1);
    }

    function setScaleFactorsAndThreshold(
        uint256 _blessThreshold,
        uint256 _blessScaleFactor,
        uint256 _scaleFactor
    ) external onlyAdmin {
        blessThreshold = _blessThreshold;
        blessScaleFactor = _blessScaleFactor;
        scaleFactor = _scaleFactor;
    }

    function bless() external updateReward(msg.sender) checkStart {
        require(block.timestamp > nextBlessingTime[msg.sender], "early bless request");
        require(numBlessing[msg.sender] < blessThreshold, "bless reach limit");
        // save current blessing price, since transfer is done last
        // since getBlessingPrice() returns new bless balance, avoid re-calculation
        (uint256 blessPrice, uint256 newBlessingBalance) = getBlessingPrice(msg.sender);
        // user's balance and blessingSupply will be changed in this function
        applyBlessing(msg.sender, newBlessingBalance);

        goddessToken.safeTransferFrom(msg.sender, address(this), blessPrice);

        ERC20Burnable burnableGoddessToken = ERC20Burnable(address(goddessToken));

        // burn 50%
        uint256 burnAmount = blessPrice.div(2);
        burnableGoddessToken.burn(burnAmount);
        blessPrice = blessPrice.sub(burnAmount);

        // swap to stablecoin
        address[] memory routeDetails = new address[](3);
        routeDetails[0] = address(goddessToken);
        routeDetails[1] = uniswapRouter.WETH();
        routeDetails[2] = address(stablecoin);
        uniswapRouter.swapExactTokensForTokens(
            blessPrice,
            0,
            routeDetails,
            governance,
            block.timestamp + 100
        );
    }

    function setGovernance(address _governance) external onlyAdmin {
        governance = _governance;
        stablecoin = IGovernance(governance).getStableToken();
    }

    function setUniswapRouter(IUniswapRouter _uniswapRouter) external onlyAdmin {
        uniswapRouter = _uniswapRouter;
        goddessToken.safeApprove(address(_uniswapRouter), 2**256 - 1);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount, address referrer) public updateReward(msg.sender) checkStart {
        _stake(amount, referrer);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount > 0, "Cannot withdraw 0");
        LPTokenWrapper.withdraw(amount);

        numBlessing[msg.sender] = 0;
        // update goddess balance and supply
        updateStakeBalanceAndSupply(msg.sender, 0);

        stakeToken.safeTransfer(msg.sender, amount);
        getReward();
    }

    function getBlessingPrice(address user)
        public
        view
        returns (uint256 blessingPrice, uint256 newBlessingBalance)
    {
        if (totalStakingBalance == 0) return (0, 0);

        // 5% increase for each previously user-purchased blessing
        uint256 blessedTime = numBlessing[user];
        blessingPrice = globalBlessPrice.mul(blessedTime.mul(5).add(100)).div(100);

        // increment blessedTime by 1
        blessedTime = blessedTime.add(1);

        // if no. of blessings exceed threshold, increase blessing price by blessScaleFactor;
        if (blessedTime >= blessThreshold) {
            return (0, balanceOf(user));
        }

        // adjust price based on expected increase in total stake supply
        // blessedTime has been incremented by 1 already
        newBlessingBalance = balanceOf(user).mul(blessedTime.mul(5).add(100)).div(100);
        uint256 blessBalanceIncrease = newBlessingBalance.sub(stakeBalance[user]);
        blessingPrice = blessingPrice.mul(blessBalanceIncrease).mul(scaleFactor).div(
            totalStakingBalance
        );
    }

    function applyBlessing(address user, uint256 newBlessingBalance) internal {
        // increase no. of blessings bought
        numBlessing[user] = numBlessing[user].add(1);

        updateStakeBalanceAndSupply(user, newBlessingBalance);

        // increase next purchase eligibility by an hour
        nextBlessingTime[user] = block.timestamp.add(3600);

        // increase global blessing price by 1%
        globalBlessPrice = globalBlessPrice.mul(101).div(100);

        lastBlessingTime = block.timestamp;
    }

    function updateGoddessBalanceAndSupply(address user) internal {
        // subtract existing balance from goddessSupply
        totalStakingBalance = totalStakingBalance.sub(stakeBalance[user]);
        // calculate and update new goddess balance (user's balance has been updated by parent method)
        // each blessing adds 5% to stake amount
        uint256 newGoddessBalance = balanceOf(user).mul(numBlessing[user].mul(5).add(100)).div(
            100
        );
        stakeBalance[user] = newGoddessBalance;
        // update totalStakingBalance
        totalStakingBalance = totalStakingBalance.add(newGoddessBalance);
    }

    function updateStakeBalanceAndSupply(address user, uint256 newBlessingBalance) private {
        totalStakingBalance = totalStakingBalance.sub(stakeBalance[user]);

        if (newBlessingBalance == 0) {
            newBlessingBalance = balanceOf(user);
        }

        stakeBalance[user] = newBlessingBalance;

        totalStakingBalance = totalStakingBalance.add(newBlessingBalance);
    }
}
