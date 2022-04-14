// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Pool} from "./Pool.sol";

contract Factory {

    mapping(address => mapping(address => address)) public getPool;

    event PoolCreated(address indexed asset0, address indexed asset1, address indexed pool);
    // error CannotBeSameAddress();

    function createPool(address assetA, address assetB) public returns(address pool){
        require(assetA != assetB, "SAME_ADDRESS_NOT_POSSIBLE");
        (address asset0, address asset1) = assetA < assetB ? (assetA, assetB) : (assetB, assetA);
        require(asset0 != address(0), "ZERO_ADDRESS");
        require(getPool[asset0][asset1] == address(0), "POOL_ALREADY_EXISTS");
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(asset0, asset1));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        Pool(pool).initialize(asset0, asset1);
        getPool[asset0][asset1] = pool;
        getPool[asset1][asset0] = pool; // populate mapping in the reverse direction
        
        emit PoolCreated(asset0, asset1, pool);
    }
}
