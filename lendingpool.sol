// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import standard ERC20 token interface
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Import Chainlink price feed interface
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title LendingPool
 * @dev A basic DeFi Lending and Borrowing smart contract with dynamic interest rates
 * @author Arka Priya Das 
 *company : CODETECH IT SOLUTIONS 
 *Intern Id : CT08DG657 Domain : BLOCKCHAIN TECHNOLOGY
 *
 */
contract lendingpool {
    // ERC20 token to be lent and borrowed (e.g. USDC, DAI)
    IERC20 public immutable token;

    // Chainlink price feed (e.g. ETH/USD)
    AggregatorV3Interface public immutable priceFeed;

    // Total tokens supplied by all users
    uint256 public totalSupplied;

    // Total tokens borrowed by all users
    uint256 public totalBorrowed;

    // Mapping of user address to amount deposited
    mapping(address => uint256) public deposits;

    // Mapping of user address to amount borrowed
    mapping(address => uint256) public borrows;

    /**
     * @dev Constructor sets the token and Chainlink price feed
     * @param _token Address of the ERC20 token
     * @param _priceFeed Address of the Chainlink price feed
     */
    constructor(address _token, address _priceFeed) {
        token = IERC20(_token);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice Deposit ERC20 tokens into the pool
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than 0");

        // Transfer tokens from user to the contract
        token.transferFrom(msg.sender, address(this), amount);

        // Update balances
        deposits[msg.sender] += amount;
        totalSupplied += amount;
    }

    /**
     * @notice Borrow tokens using your deposit as collateral
     * @param amount Amount to borrow
     */
    function borrow(uint256 amount) external {
        require(deposits[msg.sender] > 0, "No collateral deposited");

        // Get the USD value of user's deposit
        uint256 collateralValueUSD = (deposits[msg.sender] * getPrice()) / 1e8;

        // 50% Loan-to-Value ratio (LTV)
        uint256 maxBorrowUSD = collateralValueUSD / 2;

        // Ensure borrow amount doesn't exceed max
        require(amount <= maxBorrowUSD, "Borrow exceeds collateral value");

        // Ensure enough liquidity
        require(amount <= token.balanceOf(address(this)), "Insufficient pool liquidity");

        // Update state
        borrows[msg.sender] += amount;
        totalBorrowed += amount;

        // Transfer borrowed tokens to user
        token.transfer(msg.sender, amount);
    }

    /**
     * @notice Get the utilization rate of the pool
     * Utilization = totalBorrowed / totalSupplied
     */
    function getUtilizationRate() public view returns (uint256) {
        if (totalSupplied == 0) return 0;
        return (totalBorrowed * 1e18) / totalSupplied; // scaled by 1e18
    }

    /**
     * @notice Get the current dynamic borrow interest rate
     * Base Rate: 2%, Slope: 8%, max 10% total
     */
    function getBorrowInterestRate() public view returns (uint256) {
        uint256 baseRate = 2e16; // 2% in 1e18 format
        uint256 slope = 8e16;    // 8%

        uint256 utilization = getUtilizationRate(); // scaled

        // Interest = base + slope * U
        return baseRate + (utilization * slope) / 1e18;
    }

    /**
     * @notice Get the supply interest rate
     * Based on utilization and borrow interest rate
     */
    function getSupplyInterestRate() public view returns (uint256) {
        uint256 borrowRate = getBorrowInterestRate();
        uint256 utilization = getUtilizationRate();
        return (borrowRate * utilization) / 1e18;
    }

    /**
     * @notice Get latest price from Chainlink price feed
     * Example: ETH/USD feed returns 8 decimals
     */
    function getPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price); // returns price in 8 decimals
    }
}
