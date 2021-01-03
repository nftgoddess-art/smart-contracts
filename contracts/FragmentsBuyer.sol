
pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IGoddessFragments.sol";
import "./interfaces/IUniswapRouter.sol";
import "./RewardsPool.sol";

contract FragmentsBuyer is Withdrawable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IGoddessFragments public goddessFragments;
    IUniswapRouter public uniswapRouter;
    IERC20 public goddessToken;
    IERC20 public pricingToken;
    IERC20 public weth;
    uint256 public baseFragmentsPrice;
    uint256 public currentFragmentsPrice;
    uint256 public resetTime;
    address public treasury;

    constructor(
        IERC20 _goddessToken,
        IUniswapRouter _uniswapRouter,
        IGoddessFragments _goddessFragments,
        address _treasury
    )
        public  Withdrawable(msg.sender) 
    {
        goddessFragments = _goddessFragments;
        uniswapRouter = _uniswapRouter;
        goddessToken = _goddessToken;
        weth = IERC20(uniswapRouter.WETH());
        treasury = _treasury;
    }

    function setTreasury(address _treasury) external onlyAdmin {
        treasury = _treasury;
    }

    function setUniswapRouter(IUniswapRouter _uniswapRouter) external onlyAdmin {
        uniswapRouter = _uniswapRouter;
    }

    function setFragmentsPrice(IERC20 _pricingToken, uint256 _fragmentsPrice) external onlyAdmin {
        pricingToken = _pricingToken;
        baseFragmentsPrice = _fragmentsPrice;
        currentFragmentsPrice = _fragmentsPrice;
        resetTime = block.timestamp.add(86400);
    }

    function getFragmentsPrice(IERC20 token, uint256 amount) public view returns (uint256) {
        uint256 tokenAmount = currentFragmentsPrice.mul(amount).div(1e18);
        if (token == pricingToken) {
            return tokenAmount;
        }
        address[] memory routeDetails;
        if (token == weth) {
            routeDetails = new address[](2);
            routeDetails[0] = address(token);
            routeDetails[1] = address(pricingToken);
        } else {
            routeDetails = new address[](3);
            routeDetails[0] = address(token);
            routeDetails[1] = uniswapRouter.WETH();
            routeDetails[2] = address(pricingToken);
        }
        uint256[] memory amountIn = uniswapRouter.getAmountsIn(tokenAmount, routeDetails);
        return amountIn[0];
    }

    function buyFragments(IERC20 token, uint256 fragmentAmount, uint256 tokenSanityAmount, address user) external {
        if(block.timestamp >= resetTime) {
            resetTime = resetTime.add((block.timestamp.sub(resetTime).div(86400)).mul(86400));
            currentFragmentsPrice = baseFragmentsPrice;
        }
        uint256 tokenAmount = currentFragmentsPrice.mul(fragmentAmount).div(1e18);
        if (token == pricingToken) {
            require(tokenSanityAmount > tokenAmount, "sanity exceed");
            token.safeTransferFrom(msg.sender, treasury, tokenAmount);
        } else {
            address[] memory routeDetails;
            if (token == weth) {
                routeDetails = new address[](2);
                routeDetails[0] = address(token);
                routeDetails[1] = address(pricingToken);
            } else {
                routeDetails = new address[](3);
                routeDetails[0] = address(token);
                routeDetails[1] = address(weth);
                routeDetails[2] = address(pricingToken);
            }
            uint256[] memory amountIn = uniswapRouter.getAmountsIn(tokenAmount, routeDetails);
            require(tokenSanityAmount > amountIn[0], "sanity exceed");       
            if (token == goddessToken) {         
                token.safeTransferFrom(msg.sender, treasury, amountIn[0]);
                //send directly to treasury without swap
            } else {
                token.safeTransferFrom(msg.sender, address(this), amountIn[0]);
                uniswapRouter.swapTokensForExactTokens(
                    tokenAmount,
                    amountIn[0],
                    routeDetails,
                    treasury, //send directly to treasury
                    block.timestamp + 100
                );
            }
        }
        goddessFragments.collectFragments(user, fragmentAmount);
        // increase current fragment price by 1%
        currentFragmentsPrice = currentFragmentsPrice.mul(101).div(100);
    }
}
