//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

interface IReferral {
    function setReferrer(address farmer, address referrer) external;

    function getReferrer(address farmer) external view returns (address);
}
