//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/ERC20Detailed.sol";

contract SimpleToken is ERC20, ERC20Detailed {
    uint256 public INITIAL_SUPPLY = 10**(50 + 18);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public ERC20Detailed(_name, _symbol, _decimals) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
