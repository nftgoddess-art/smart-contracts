pragma solidity ^0.5.12;

interface IGoddess {
    function create(uint256 _maxSupply) external returns (uint256);

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes calldata _data
    ) external;

    function burn(
        address _from,
        uint256 _id,
        uint256 _amount
    ) external;

    function totalSupply(uint256 _id) external view returns (uint256);

    function maxSupply(uint256 _id) external view returns (uint256);

    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
}
