//SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.5.17;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
