//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionGroups.sol";

contract Withdrawable is PermissionGroups {
    mapping(address => bool) internal blacklist;

    event TokenWithdraw(IERC20 token, uint256 amount, address sendTo);

    event EtherWithdraw(uint256 amount, address sendTo);

    constructor(address _admin) public PermissionGroups(_admin) {}

    /**
     * @dev Withdraw all IERC20 compatible tokens
     * @param token IERC20 The address of the token contract
     */
    function withdrawToken(
        IERC20 token,
        uint256 amount,
        address sendTo
    ) external onlyAdmin {
        require(!blacklist[address(token)], "forbid to withdraw that token");
        token.transfer(sendTo, amount);
        emit TokenWithdraw(token, amount, sendTo);
    }

    /**
     * @dev Withdraw Ethers
     */
    function withdrawEther(uint256 amount, address payable sendTo) external onlyAdmin {
        (bool success, ) = sendTo.call.value(amount)("");
        require(success);
        emit EtherWithdraw(amount, sendTo);
    }

    function setBlackList(address token) internal {
        blacklist[token] = true;
    }
}
