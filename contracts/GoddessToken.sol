//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./utils/ERC20Detailed.sol";
import "./utils/Withdrawable.sol";

contract GoddessToken is ERC20, ERC20Detailed, ERC20Burnable, Withdrawable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    constructor() public ERC20Detailed("Goddess Token", "GDS", 18) Withdrawable(msg.sender) {
        _mint(msg.sender, 1e24);
    }
}
