pragma solidity ^0.5.0;

import "./utils/Withdrawable.sol";

contract Referral is Withdrawable {
    mapping(address => address) public referrers; // account_address -> referrer_address
    mapping(address => uint256) public referredCount; // referrer_address -> num_of_referred

    event ReferralSet(address indexed referrer, address indexed farmer);

    constructor(address _admin) public Withdrawable(_admin) {}

    function setReferrer(address farmer, address referrer) public onlyOperator {
        if (referrers[farmer] == address(0) && referrer != address(0)) {
            referrers[farmer] = referrer;
            referredCount[referrer] += 1;
            emit ReferralSet(referrer, farmer);
        }
    }

    function getReferrer(address farmer) public view returns (address) {
        return referrers[farmer];
    }
}
