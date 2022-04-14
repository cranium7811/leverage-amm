// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {Factory} from "../Factory.sol";
import {Pool} from "../Pool.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract FactoryTest is DSTest {

    Factory public factory;
    Pool public pool;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        factory = new Factory();
        pool = new Pool();
    }

    function testCreatePool() public {
        emit log_address(factory.createPool(WETH, USDC));
    }
}
