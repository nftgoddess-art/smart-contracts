//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./utils/Withdrawable.sol";

contract GoddessTreasury is Withdrawable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public stableToken;
    IERC20 public goddessToken;
    uint256 public vestingAmount;
    uint256 public vestingBegin;
    uint256 public vestingEnd;

    constructor(
        IERC20 _stableToken,
        IERC20 _goddessToken,
        uint256 vestingAmount_,
        uint256 vestingBegin_,
        uint256 vestingEnd_,
        address _admin
    ) public Withdrawable(_admin) {
        require(
            vestingBegin_ >= block.timestamp,
            "TreasuryVester::constructor: vesting begin too early"
        );
        require(vestingEnd_ > vestingBegin_, "TreasuryVester::constructor: end is too early");
        stableToken = _stableToken;
        goddessToken = _goddessToken;
        Withdrawable.setBlackList(address(_goddessToken));
        vestingAmount = vestingAmount_;
        vestingBegin = vestingBegin_;
        vestingEnd = vestingEnd_;
    }

    function getStableToken() external view returns (address) {
        return address(stableToken);
    }

    function setStableToken(IERC20 _stableToken) external onlyAdmin {
        stableToken = _stableToken;
    }

    function claim(address sendTo) external onlyAdmin {
        require(block.timestamp >= vestingBegin, "TreasuryVester::claim: not time yet");
        uint256 lockAmount;
        if (block.timestamp <= vestingEnd) {
            lockAmount = vestingAmount.mul(vestingEnd - block.timestamp).div(
                vestingEnd - vestingBegin
            );
        }
        uint256 amount = goddessToken.balanceOf(address(this)).sub(lockAmount);
        goddessToken.safeTransfer(sendTo, amount);
    }
}
