//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "multi-token-standard/contracts/tokens/ERC1155/ERC1155.sol";
import "multi-token-standard/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import "multi-token-standard/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import "./utils/Strings.sol";
import "./utils/Withdrawable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract Goddess is ERC1155, ERC1155MintBurn, ERC1155Metadata, Withdrawable {
    using Strings for string;

    address proxyRegistryAddress;
    uint256 private _currentTokenID = 0;
    mapping(uint256 => uint256) private tokenSupply;
    mapping(uint256 => uint256) private tokenMaxSupply;
    mapping(uint256 => uint256) public nextLevel;
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    modifier ownersOnly(uint256 _id) {
        require(balances[msg.sender][_id] > 0, "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress
    ) public Withdrawable(msg.sender) {
        name = _name;
        symbol = _symbol;
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function uri(uint256 _id) public view returns (string memory) {
        require(_exists(_id), "ERC721Tradable#uri: NONEXISTENT_TOKEN");
        return Strings.strConcat(baseMetadataURI, Strings.uint2str(_id));
    }

    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    function setBaseMetadataURI(string memory _newBaseMetadataURI) public onlyAdmin {
        _setBaseMetadataURI(_newBaseMetadataURI);
    }

    function setProxyRegistryAddress(address _proxyRegistryAddress) external onlyAdmin {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function create(uint256 _maxSupply) external onlyOperator returns (uint256) {
        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        tokenMaxSupply[_id] = _maxSupply;
        return _id;
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public onlyOperator {
        require(tokenSupply[_id] < tokenMaxSupply[_id], "Max supply reached");
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id].add(_quantity);
    }

    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public onlyOperator {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id].add(quantity);
        }
        _batchMint(_to, _ids, _quantities, _data);
    }

    function burn(
        address _from,
        uint256 _id,
        uint256 _amount
    ) public onlyOperator {
        _burn(_from, _id, _amount);
        tokenMaxSupply[_id] = tokenMaxSupply[_id].sub(_amount);
        tokenSupply[_id] = tokenSupply[_id].sub(_amount);
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        returns (bool isOperator)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return _id <= _currentTokenID;
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID.add(1);
    }

    /**
     * @dev increments the value of _currentTokenID
     */
    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }

    function maxSupply(uint256 _id) public view returns (uint256) {
        return tokenMaxSupply[_id];
    }
}
