// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

struct Position {
    uint8 leverage;
    uint112 depositedAmount;
}

contract Pool {


    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/


    address public immutable factory;
    address public asset0;
    address public asset1;

    uint112 private reserve0;
    uint112 private reserve1;

    mapping(address => bool) public positionOpen;
    mapping(address => Position) public traderPosition;


    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/


    error MaxLeverage10x();
    error NotEnoughLiquidity();
    error NoTradesOpen();
    error ShouldBeMoreThanZero();
    error NotFactoryOwner();


    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/


    modifier maxLeverage(uint8 leverage) {
        if(leverage == 0 && leverage >10) revert MaxLeverage10x();
        _;
    }


    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/


    constructor() {
        factory = msg.sender;
    }


    /*//////////////////////////////////////////////////////////////
                            INITIALIZE
    //////////////////////////////////////////////////////////////*/


    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param _asset0 a parameter just like in doxygen (must be followed by parameter name)
    /// @param _asset1 a parameter just like in doxygen (must be followed by parameter name)
    function initialize(address _asset0, address _asset1) public {
        if(msg.sender != factory) revert NotFactoryOwner();
        asset0 = _asset0;
        asset1 = _asset1;
    }


    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    function getReserves() internal view returns(uint112, uint112){
        return (reserve0, reserve1);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param amountA a parameter just like in doxygen (must be followed by parameter name)
    /// @param leverage a parameter just like in doxygen (must be followed by parameter name)
    function getAmountBAfterSwap(
        uint112 amountA,
        uint8 leverage
    ) internal view maxLeverage(leverage) returns(uint112 amountB){
        uint112 amountWithLeverage = amountA * leverage;
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        if(amountWithLeverage > _reserve0) revert NotEnoughLiquidity();
        amountB = (amountWithLeverage * _reserve1) / (_reserve0 + amountWithLeverage);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param amountB a parameter just like in doxygen (must be followed by parameter name)
    /// @param leverage a parameter just like in doxygen (must be followed by parameter name)
    function getAmountANeededForSwap(
        uint112 amountB, 
        uint8 leverage
    ) internal view maxLeverage(leverage) returns(uint112 amountA){
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        if(amountB > _reserve1) revert NotEnoughLiquidity();
        uint112 amountWithLeverage = (amountB * _reserve0) / (_reserve1 + amountB);
        amountA = amountWithLeverage / leverage;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    function getRemainingValue() internal view returns(uint112 remainingValue) {
        if(!positionOpen[msg.sender]) revert NoTradesOpen();
        Position storage position = traderPosition[msg.sender];
        remainingValue = position.depositedAmount * (10 - position.leverage);
    }


    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param amountA a parameter just like in doxygen (must be followed by parameter name)
    function depositUsdc(uint112 amountA) public {
        if(amountA == 0) revert ShouldBeMoreThanZero();
        (uint112 _reserve0, ) = getReserves();
        traderPosition[msg.sender].depositedAmount = amountA;
        
        reserve0 = _reserve0 + amountA;
        ERC20(asset0).transferFrom(msg.sender, address(this), amountA);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param leverage a parameter just like in doxygen (must be followed by parameter name)
    function createPosition(uint8 leverage) public maxLeverage(leverage) {
        if(!positionOpen[msg.sender]) revert NoTradesOpen();
        (, uint112 _reserve1) = getReserves();

        uint112 amountB = getAmountBAfterSwap(traderPosition[msg.sender].depositedAmount, leverage);
        if(amountB > _reserve1) revert NotEnoughLiquidity();

        reserve1 = _reserve1 + amountB;
        ERC20(asset1).transfer(msg.sender, amountB);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param asset a parameter just like in doxygen (must be followed by parameter name)
    function getPriceFeed(address asset) public {

    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param position a parameter just like in doxygen (must be followed by parameter name)
    function liquidate(Position memory position) public {

    }
}
