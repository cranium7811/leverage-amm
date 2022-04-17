// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import {Pool} from "../Pool.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Factory} from "../Factory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract PoolTest is DSTest {
    using stdStorage for StdStorage;
    StdStorage public stdstore;

    address public immutable usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IPool public pool;
    Factory public factory;

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(ERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function setUp() public {
        pool = new Pool();
        factory = new Factory();

        writeTokenBalance(address(msg.sender), address(usdc), 1000000000 * 1e18);
        writeTokenBalance(address(this), address(usdc), 1000000000 * 1e18);
    }

    function testGetPerpAmountAfterSwap() public {
        uint256 amountB = pool.getPerpAmountAfterSwap(500e18, 1);

        emit log_uint(amountB);
    }

    function testGetBaseAmountNeededForSwap() public {
        uint256 amountB = pool.getBaseAmountNeededForSwap(5e18, 1);

        emit log_uint(amountB);
    }

    function testDepositBase() public {
        ERC20(usdc).approve(address(this), type(uint256).max);
        ERC20(usdc).approve(address(pool), type(uint256).max);

        uint256 usdcBalanceThis = ERC20(usdc).balanceOf(address(this));

        pool.depositBase(500e18);

        IPool.Position memory position = IPool(pool).traderPosition(address(this));

        (uint256 baseReserve, uint256 perpReserve) = IPool(pool).getReserves();

        assertEq(position.depositedAmount, 500e18);
        assertEq(baseReserve, 20000e18 + 500e18);
        assertEq(perpReserve, 100e18);
        assertEq(ERC20(usdc).balanceOf(address(pool)), 500e18);
        assertEq(ERC20(usdc).balanceOf(address(this)), usdcBalanceThis - 500e18);
    }

    function testOpenPosition() public {
        ERC20(usdc).approve(address(this), type(uint256).max);
        ERC20(usdc).approve(address(pool), type(uint256).max);

        uint256 usdcBalanceThis = ERC20(usdc).balanceOf(address(this));

        pool.depositBase(500e18);

        pool.openPosition(0, 1);

        IPool.Position memory position = IPool(pool).traderPosition(address(this));

        (uint256 baseReserve, uint256 perpReserve) = IPool(pool).getReserves();

        assertEq(position.depositedAmount, 500e18);
        assertEq(position.leverage, 1);
        assertEq(position.positionValue, 500e18);
        assertEq(ERC20(usdc).balanceOf(address(pool)), 500e18);
        assertEq(ERC20(usdc).balanceOf(address(this)), usdcBalanceThis - 500e18);
        assertEq(baseReserve, 20000e18 + 500e18);
        emit log_uint(perpReserve);
    }

    function testClosePosition() public {
        ERC20(usdc).approve(address(this), type(uint256).max);
        ERC20(usdc).approve(address(pool), type(uint256).max);

        uint256 usdcBalanceThis = ERC20(usdc).balanceOf(address(this));

        pool.depositBase(500e18);

        pool.openPosition(0, 1);

        pool.closePosition();

        IPool.Position memory position = IPool(pool).traderPosition(address(this));

        assertEq(position.depositedAmount, 0);
        assertEq(position.leverage, 1);
        assertEq(position.positionValue, 0);
        assertEq(ERC20(usdc).balanceOf(address(pool)), 0);
        assertEq(ERC20(usdc).balanceOf(address(this)), usdcBalanceThis);
    }

    function testChangeLeverage() public {
        ERC20(usdc).approve(address(this), type(uint256).max);
        ERC20(usdc).approve(address(pool), type(uint256).max);

        uint256 usdcBalanceThis = ERC20(usdc).balanceOf(address(this));

        pool.depositBase(500e18);

        pool.openPosition(0, 1);

        pool.changeLeverage(2);

        IPool.Position memory position = IPool(pool).traderPosition(address(this));

        (uint256 baseReserve, uint256 perpReserve) = IPool(pool).getReserves();

        assertEq(position.depositedAmount, 500e18);
        assertEq(position.leverage, 2);
        assertEq(position.positionValue, 1000e18);
        assertEq(ERC20(usdc).balanceOf(address(pool)), 500e18);
        assertEq(ERC20(usdc).balanceOf(address(this)), usdcBalanceThis - 500e18);
        assertEq(baseReserve, 20000e18 + 500e18);
        emit log_uint(perpReserve); //93078626799557032116
    }
}
