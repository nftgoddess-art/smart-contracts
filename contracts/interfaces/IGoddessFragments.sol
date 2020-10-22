//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

interface IGoddessFragments {
    function summon(uint256 goddessID) external;

    function fusion(uint256 goddessID) external;

    function collectFragments(address user, uint256 amount) external;
}
