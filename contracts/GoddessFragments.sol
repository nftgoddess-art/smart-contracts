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

    mapping(address => uint256) private fragments;
    mapping(uint256 => uint256) public summonRequire;
    mapping(uint256 => uint256) public fusionRequire;
    mapping(uint256 => uint256) public nextLevel;
    mapping(uint256 => address) public authors;

    uint256 public totalFragments;
    uint256 public fusionFee;
    uint256 public burnInBps;
    uint256 public treasuryInBps;
    IGoddess public goddess;
    IERC20 public goddessToken;

    IUniswapRouter public uniswapRouter;
    IERC20 public stablecoin;
    address public treasury;

    constructor(
        address _admin,
        IERC20 _goddessToken,
        address _goddess,
        IUniswapRouter _uniswapRouter,
        address _treasury
    ) public Withdrawable(_admin) {
        goddessToken = _goddessToken;
        goddess = IGoddess(_goddess);
        uniswapRouter = _uniswapRouter;
        goddessToken.safeApprove(address(_uniswapRouter), 2**256 - 1);
        treasury = _treasury;
    }

    event GoddessAdded(uint256 goddessID, uint256 fragments);
    event Staked(address indexed user, uint256 amount);
    event FusionFee(
        IERC20 stablecoin,
        uint256 fusionFee,
        uint256 burnInBps,
        uint256 treasuryInBps
    );

    function collectFragments(address user, uint256 amount) external onlyOperator {
        totalFragments = totalFragments.add(amount);
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
        totalFragments.sub(summonRequire[goddessID]);
        goddess.mint(msg.sender, goddessID, 1, "");
    }

    function fusionFeeInGds() public view returns (uint256) {
        address[] memory routeDetails = new address[](3);
        routeDetails[0] = address(goddessToken);
        routeDetails[1] = uniswapRouter.WETH();
        routeDetails[2] = address(stablecoin);
        uint256[] memory amounts = uniswapRouter.getAmountsIn(fusionFee, routeDetails);
        return amounts[0].mul(burnInBps.add(10000)).div(10000);
    }

    function fuse(uint256 goddessID) public {
        uint256 nextLevelID = nextLevel[goddessID];
        uint256 fusionAmount = fusionRequire[goddessID];
        require(nextLevelID != 0, "there is no higher level of this goddess");
        require(
            goddess.balanceOf(msg.sender, goddessID) >= fusionAmount,
            "not enough goddess for fusion"
        );
        require(address(stablecoin) != address(0), "stable coin not set");

        address[] memory routeDetails = new address[](3);
        routeDetails[0] = address(goddessToken);
        routeDetails[1] = uniswapRouter.WETH();
        routeDetails[2] = address(stablecoin);
        uint256[] memory amounts = uniswapRouter.getAmountsIn(fusionFee, routeDetails);
        uint256 burnAmount = amounts[0].mul(burnInBps).div(10000);
        goddessToken.safeTransferFrom(msg.sender, address(this), burnAmount.add(amounts[0]));

        // swap to stablecoin, transferred to author
        address author = authors[goddessID];
        uniswapRouter.swapTokensForExactTokens(
            fusionFee,
            amounts[0],
            routeDetails,
            address(this),
            block.timestamp + 100
        );
        if (treasury != address(0)) {
            uint256 treasuryAmount = fusionFee.mul(treasuryInBps).div(10000);
            stablecoin.safeTransfer(treasury, treasuryAmount);
            stablecoin.safeTransfer(author, fusionFee.sub(treasuryAmount));
        } else {
            stablecoin.safeTransfer(author, fusionFee);
        }

        ERC20Burnable burnableGoddessToken = ERC20Burnable(address(goddessToken));
        burnableGoddessToken.burn(burnAmount);

        goddess.burn(msg.sender, goddessID, fusionAmount);
        goddess.mint(msg.sender, nextLevelID, 1, "");
    }

    function setUniswapRouter(IUniswapRouter _uniswapRouter) external onlyAdmin {
        uniswapRouter = _uniswapRouter;
        goddessToken.safeApprove(address(_uniswapRouter), 2**256 - 1);
    }

    function setFusionFee(
        IERC20 _stablecoin,
        uint256 _fusionFee,
        uint256 _burnInBps,
        uint256 _treasuryInBps
    ) external onlyAdmin {
        stablecoin = _stablecoin;
        burnInBps = _burnInBps;
        fusionFee = _fusionFee;
        treasuryInBps = _treasuryInBps;
        emit FusionFee(stablecoin, fusionFee, burnInBps, treasuryInBps);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        treasury = _treasury;
    }
}
