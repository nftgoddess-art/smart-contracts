//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PermissionGroups.sol";

contract Withdrawable is PermissionGroups {
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    mapping(address => bool) internal blacklist;

    event TokenWithdraw(address token, uint256 amount, address sendTo);

    event EtherWithdraw(uint256 amount, address sendTo);

    constructor(address _admin) public PermissionGroups(_admin) {}

    /**
     * @dev Withdraw all IERC20 compatible tokens
     * @param token IERC20 The address of the token contract
     */
    function withdrawToken(
        address token,
        uint256 amount,
        address sendTo
    ) external onlyAdmin {
        require(!blacklist[address(token)], "forbid to withdraw that token");
        _safeTransfer(token, sendTo, amount);
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

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
}
