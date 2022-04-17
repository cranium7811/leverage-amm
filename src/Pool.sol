// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {DecimalMath} from "./utils/DecimalMath.sol";
import {IPool} from "./interfaces/IPool.sol";


/// @title An AMM pool
/// @notice There are no price feeds (oracles), liquidations and fees added
/// @dev Just a simple version
contract Pool is IPool{
    using DecimalMath for DecimalMath.UFixed;
    using DecimalMath for uint256;

    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Address of the factory contract which is immutable
    address public immutable factory;
    // Address of the baseAsset which is the settlement asset. Generally, a stablecoin
    address public baseAsset = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //USDC - For testing purpose
    // Address of the asset which is being speculated as a perp 
    address public perpAsset;

    // Reserve of the base asset
    uint256 private baseReserve = 20000e18;     //For testing purpose
    // Reserve of the perp asset
    uint256 private perpReserve = 100e18;       //For testing purpose

    // Mapping to check if a trader has a position/trade open
    mapping(address => bool) internal _positionOpen;
    // Mapping to identify the position/trade of the trader
    // see struct Position in `IPool.sol`
    mapping(address => Position) internal _traderPosition;


    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    // Used custom errors for saving gas and can add args if required
    // Max leverage cannot be more than 10
    error MaxLeverage10x();
    // Not enough Liquidity
    error NotEnoughLiquidity();
    // There are no positions open for the `msg.sender`(trader)
    error NoPositionOpen();
    // The amount sent should be more than 0
    error ShouldBeMoreThanZero();
    // `initialize` can only be called by the factory owner
    error NotFactoryOwner();
    // Position is already open
    error PositionAlreadyOpen();

    /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/


    event DepositedBaseAsset(uint256 depositedAmount, address indexed trader);
    event PositionOpened(uint256 depositedAmount, address indexed trader, uint8 leverage);
    event PositionClosed(uint256 amountReceivedByTrader, address indexed trader);
    event LeverageChanged(uint8 newLeverage, address indexed trader, uint256 depositedBaseAmount);


    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Modifier to check if the given leverage is less than 10 and more than 0
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


    /// @notice intialize the amm pool from the factory contract
    /// @param _baseAsset the base asset which is generally a stablecoin (usdc in this case)
    /// @param _perpAsset the other asset in the amm pool which is being speculated as perp
    function initialize(address _baseAsset, address _perpAsset) public {
        if(msg.sender != factory) revert NotFactoryOwner();
        baseAsset = _baseAsset;
        perpAsset = _perpAsset;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice view function to get the `traderPosition` mapping
    function traderPosition(address trader) external view returns(Position memory position) {
        position = _traderPosition[trader];
    }

    /// @notice view function to get the `positionOpen` mapping
    function positionOpen(address trader) external view returns(bool open) {
        open = _positionOpen[trader];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    /// @notice Get the reserves in the amm pool
    function getReserves() public view returns(uint256, uint256){
        return (baseReserve, perpReserve);
    }

    /// @notice Get the perp amount which will happen after the swap
    /// @dev caluclation explained inside the block using Uniswap's XY = K
    /// @dev made it public for testing purposes
    /// @param baseAmount the amount which is being deposited in this contract for a trade
    /// @param leverage the leverage of the trade which is from 0 to 10
    /// @return perpAmount the amount which the trader gets after the swap
    function getPerpAmountAfterSwap(
        uint256 baseAmount,
        uint8 leverage
    ) public view maxLeverage(leverage) returns(uint256 perpAmount){

        uint256 amountWithLeverage = baseAmount * leverage;
        (uint256 _baseReserve, uint256 _perpReserve) = getReserves();
        if(amountWithLeverage > _baseReserve) revert NotEnoughLiquidity();

        // X, Y - existing reserves in the pool
        // x, y - tokens to be swapped
        // (X + x) * (Y + y) = X * Y
        // y = (x * Y) / X + x
        // Since it's in Decimal, the value has to be divided by DecimalMath.UNIT to get the (10 ^ 18) value
        perpAmount = (amountWithLeverage * _perpReserve).toUFixed()
                    .divd((_baseReserve + amountWithLeverage).toUFixed()).value / DecimalMath.UNIT;
    }

    /// @notice Get the Base amount which is needed for the desired perp amount with an appropriate leverage
    /// @dev made it public for testing purposes
    /// @param perpAmount the amount which is desired after the swap
    /// @param leverage the leverage with which a trader is willing to trade
    /// @return baseAmount the minimum amount which is needed for the swap/trade to occur with the leverage
    function getBaseAmountNeededForSwap(
        uint256 perpAmount, 
        uint8 leverage
    ) public view maxLeverage(leverage) returns(uint256 baseAmount){
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        if(perpAmount > _reserve1) revert NotEnoughLiquidity();

        // X, Y - existing reserves in the pool
        // x, y - tokens to be swapped
        // (X + x) * (Y + y) = X * Y
        // x = (y * X) / Y + y
        // Since it's in Decimal, the value has to be divided by DecimalMath.UNIT to get the (10 ^ 18) value
        DecimalMath.UFixed memory amountWithLeverage = (perpAmount * _reserve0).toUFixed()
                                                        .divd((_reserve1 + perpAmount).toUFixed());
        baseAmount = (amountWithLeverage.value / leverage) / DecimalMath.UNIT;
    }

    /// @notice Get the remaining value of positions which can be exercised by a trader
    /// @dev made it public for testing purposes
    /// @return remainingValue the value which is remaining from the existing position
    function getRemainingValue() public view returns(uint256 remainingValue) {
        if(!_positionOpen[msg.sender]) revert NoPositionOpen();
        Position storage position = _traderPosition[msg.sender];

        // remainingValue = (depositedAmount * maxLeverage) - the existing value
        remainingValue = position.depositedAmount * 10 - position.positionValue;
    }


    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    

    /// @notice Deposit the stable asset to this amm pool
    /// @dev reserve updation is very minimal since no oracles/price feeds have been added
    /// @dev have to be approved before calling this method
    /// @param _baseAmount amount the trader is willing to deposit to open a position in the future
    function depositBase(uint256 _baseAmount) public {
        if(_baseAmount == 0) revert ShouldBeMoreThanZero();
        (uint256 _baseReserve, ) = getReserves();

        baseReserve = _baseReserve + _baseAmount;
        _traderPosition[msg.sender].depositedAmount = _baseAmount;
        ERC20(baseAsset).transferFrom(msg.sender, address(this), _baseAmount);

        emit DepositedBaseAsset(_baseAmount, msg.sender);
    }

    /// @notice Open a position with the amount which is already deposited by the trader
    /// @dev updating reserves is very minimal since no oracles/price feeds have been added
    /// @dev have to be approved before calling this method
    /// @dev calls `depositBase` if depositedAmount for the trader is 0.
    /// @param _baseAmountForPosition can be a new amount or 0
    /// @param leverage the leverage with which a trader wants to open a position
    function openPosition(uint256 _baseAmountForPosition, uint8 leverage) public maxLeverage(leverage) {
        if(_positionOpen[msg.sender]) revert PositionAlreadyOpen();

        Position storage position = _traderPosition[msg.sender];

        if(position.depositedAmount == 0) depositBase(_baseAmountForPosition);

        if(_baseAmountForPosition > position.depositedAmount) {
            _baseAmountForPosition = position.depositedAmount;
        }
        (, uint256 _perpReserve) = getReserves();

        uint256 perpAmountAfterSwap = getPerpAmountAfterSwap(position.depositedAmount, leverage);
        if(perpAmountAfterSwap > _perpReserve) revert NotEnoughLiquidity();

        perpReserve = _perpReserve - perpAmountAfterSwap;
        _positionOpen[msg.sender] = true;
        position.leverage = leverage;
        position.positionValue = position.depositedAmount * leverage;

        emit PositionOpened(position.depositedAmount, msg.sender, position.leverage);
    }

    /// @notice Closes an existing position
    /// @dev updating reserves is very minimal since no oracles/price feeds have been added
    /// @dev closes the entire position, can be made dynamic later
    /// @dev this is just for a simple understanding, since the depositedAmount is again transferred back to the trader
    /// @dev need to add oracles, liquidations and fees for a dynamic method.
    function closePosition() public {
        if(!_positionOpen[msg.sender]) revert NoPositionOpen();
        Position storage position = _traderPosition[msg.sender];

        (uint256 _baseReserve,) = getReserves();

        uint256 baseAmountTraderReceives = position.depositedAmount;

        if(baseAmountTraderReceives > _baseReserve) revert NotEnoughLiquidity();

        baseReserve = _baseReserve - baseAmountTraderReceives;
        _positionOpen[msg.sender] = false;
        position.depositedAmount = 0;
        position.positionValue = 0;

        ERC20(baseAsset).transfer(msg.sender, baseAmountTraderReceives);

        emit PositionClosed(baseAmountTraderReceives, msg.sender);
    }

    /// @notice Changes to a new leverage and updates the position
    /// @dev updating reserves is very minimal since no oracles/price feeds have been added
    /// @dev this is just for a simple understanding, since the depositedAmount is again transferred back to the trader
    /// @param newLeverage the new leverage which the trader wants to trade with
    function changeLeverage(uint8 newLeverage) public maxLeverage(newLeverage) {
        if(!_positionOpen[msg.sender]) revert NoPositionOpen();

        Position storage position = _traderPosition[msg.sender];

        (, uint256 _perpReserve) = getReserves();

        uint256 perpAmountAfterSwap = getPerpAmountAfterSwap(position.depositedAmount, newLeverage);
        if(perpAmountAfterSwap > _perpReserve) revert NotEnoughLiquidity();

        perpReserve = _perpReserve - perpAmountAfterSwap;
        position.leverage = newLeverage;
        position.positionValue = position.depositedAmount * newLeverage;

        emit LeverageChanged(position.leverage, msg.sender, position.depositedAmount);
    }
}
