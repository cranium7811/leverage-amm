// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Pool} from "./Pool.sol";

contract Factory {

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Mapping to get the address of the amm pool with both the asset addresses
    mapping(address => mapping(address => address)) public getPool;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolCreated(address indexed _baseAsset, address indexed _perpAsset, address indexed pool);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error SameAddress();
    error ZeroAddress();
    error PoolAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a pool (From Uniswap v2)
    /// @dev changed require statement to custom errors for gas savings
    /// @param baseAsset base asset of the pool which is generally a stablecoin
    /// @param perpAsset the other asset in the amm pool which is being speculated
    /// @return pool the address of the amm pool
    function createPool(address baseAsset, address perpAsset) public returns(address pool){
        if(baseAsset == perpAsset) revert SameAddress();
        (address _baseAsset, address _perpAsset) = baseAsset < perpAsset ? (baseAsset, perpAsset) : (perpAsset, baseAsset);
        if(_baseAsset == address(0)) revert ZeroAddress();
        if(getPool[_baseAsset][_perpAsset] != address(0)) revert PoolAlreadyExists();
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_baseAsset, _perpAsset));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        Pool(pool).initialize(_baseAsset, _perpAsset);
        getPool[_baseAsset][_perpAsset] = pool;
        getPool[_perpAsset][_baseAsset] = pool; 
        
        emit PoolCreated(_baseAsset, _perpAsset, pool);
    }

    /// Add fees functions if required
}
