// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IPool {

    struct Position {
        uint8 leverage;
        uint256 depositedAmount;
        uint256 positionValue;
    }

    function factory() external view returns(address);

    function baseAsset() external view returns(address);

    function perpAsset() external view returns(address);

    function positionOpen(address trader) view external returns(bool);

    function traderPosition(address trader) external view returns(Position memory);

    function getReserves() external view returns(uint256, uint256);

    function initialize(address baseAsset, address perpAsset) external;

    function getPerpAmountAfterSwap(uint256 baseAmount, uint8 leverage) external returns(uint256);

    function getBaseAmountNeededForSwap(uint256 perpAmount, uint8 leverage) external returns(uint256);

    function getRemainingValue() external returns(uint256);

    function depositBase(uint256 baseAmount) external;

    function openPosition(uint256 baseAmount, uint8 leverage) external;

    function closePosition() external;

    function changeLeverage(uint8 newLeverage) external;
}