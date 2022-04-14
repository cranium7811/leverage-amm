// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {Pool} from "../Pool.sol";
import {Factory} from "../Factory.sol";

contract PoolTest is DSTest {

    Pool public pool;
    Factory public factory;

    function setUp() public {
        pool = new Pool();
        factory = new Factory();
    }

    function testGetAmountBAfterSwap() public {
        uint112 amountB = pool.getAmountBAfterSwap(6000, 1);

        emit log_uint(amountB);
    }

    function testGetAmountANeededForSwap() public {
        uint112 amountA = pool.getAmountANeededForSwap(375, 1);

        emit log_uint(amountA);
    }
}
