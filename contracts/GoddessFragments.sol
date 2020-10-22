//SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "./utils/Withdrawable.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IGoddess.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract GoddessFragments is Withdrawable {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping(address => uint256) public fragments;
    mapping(uint256 => uint256) public summonRequire;
    mapping(uint256 => uint256) public fusionRequire;
    mapping(uint256 => uint256) public nextLevel;
    mapping(uint256 => address) public authors;

    uint256 minted;
    uint256 fusionFee;
    IGoddess goddess;
    IERC20 goddessToken;

    IUniswapRouter public uniswapRouter;
    address public stablecoin;

    constructor(
        address _admin,
        IERC20 _goddessToken,
        address _goddess,
        IUniswapRouter _uniswapRouter
    ) public Withdrawable(_admin) {
        goddessToken = _goddessToken;
        goddess = IGoddess(_goddess);
        uniswapRouter = _uniswapRouter;
    }

    event GoddessAdded(uint256 goddessID, uint256 fragments);
    event Staked(address indexed user, uint256 amount);
    event FusionFee(uint256 fee);

    function collectFragments(address user, uint256 amount) external onlyOperator {
        minted.add(amount);
        fragments[user] = fragments[user].add(amount);
    }

    function balanceOf(address user) external view returns (uint256) {
        return fragments[user];
    }

    function addGoddess(
        uint256 maxQuantity,
        uint256 numFragments,
        address author
    ) public onlyOperator {
        uint256 goddessID = goddess.create(maxQuantity);
        summonRequire[goddessID] = numFragments;
        authors[goddessID] = author;
        emit GoddessAdded(goddessID, numFragments);
    }

    function addNextLevelGoddess(uint256 goddessID, uint256 fusionAmount)
        public
        onlyOperator
        returns (uint256)
    {
        uint256 maxSupply = goddess.maxSupply(goddessID);
        uint256 nextLevelMaxSupply = maxSupply.div(fusionAmount);
        uint256 nextLevelID = goddess.create(nextLevelMaxSupply);
        nextLevel[goddessID] = nextLevelID;
        fusionRequire[goddessID] = fusionAmount;
        authors[nextLevelID] = authors[goddessID];
    }

    function summon(uint256 goddessID) public {
        require(summonRequire[goddessID] != 0, "Goddess not found");
        require(
            fragments[msg.sender] >= summonRequire[goddessID],
            "Not enough fragments to summon for goddess"
        );
        require(
            goddess.totalSupply(goddessID) < goddess.maxSupply(goddessID),
            "Max goddess summon"
        );
        fragments[msg.sender] = fragments[msg.sender].sub(summonRequire[goddessID]);
        goddess.mint(msg.sender, goddessID, 1, "");
    }

    function fusionFeeInGds() public view returns (uint256) {
        address[] memory routeDetails = new address[](3);
        routeDetails[0] = address(goddessToken);
        routeDetails[1] = uniswapRouter.WETH();
        routeDetails[2] = stablecoin;
        uint256[] memory amounts = uniswapRouter.getAmountsIn(fusionFee, routeDetails);
        return 2 * amounts[0];
    }

    function fusion(uint256 goddessID) public {
        uint256 nextLevelID = nextLevel[goddessID];
        uint256 fusionAmount = fusionRequire[goddessID];
        require(nextLevelID != 0, "there is no higher level of this goddess");
        require(
            goddess.balanceOf(msg.sender, goddessID) >= fusionAmount,
            "not enough goddess to fusion"
        );
        require(stablecoin != address(0), "stable coin not set");

        address[] memory routeDetails = new address[](3);
        routeDetails[0] = address(goddessToken);
        routeDetails[1] = uniswapRouter.WETH();
        routeDetails[2] = stablecoin;
        uint256[] memory amounts = uniswapRouter.getAmountsIn(fusionFee, routeDetails);

        goddessToken.safeTransferFrom(msg.sender, address(this), 2 * amounts[0]);

        ERC20Burnable burnableGoddessToken = ERC20Burnable(address(goddessToken));

        burnableGoddessToken.burn(amounts[0]); // burn half

        // swap to stablecoin, transferred to author
        address author = authors[goddessID];
        uniswapRouter.swapExactTokensForTokens(
            amounts[0],
            0,
            routeDetails,
            author,
            block.timestamp + 100
        );

        goddess.burn(msg.sender, goddessID, fusionAmount);
        goddess.mint(msg.sender, nextLevelID, 1, "");
    }

    function setStableCoin(address _stableCoin) external onlyAdmin {
        stablecoin = _stableCoin;
    }

    function setFusionFee(uint256 _fusionFee) external onlyAdmin {
        fusionFee = _fusionFee;
        emit FusionFee(fusionFee);
    }
}
