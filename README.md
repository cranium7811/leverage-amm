# Leverage-AMM

A very minimal AMM with leverage.

## Installation

Install [foundry](https://github.com/gakonst/foundry) and run `forge install` to install all the dependencies. Then run `forge test` to test the contracts.

## Testing

For a particular contract to be test use with logs and traces

```
forge test --match-contract <CONTRACT-NAME> -vvvv
```

And for forking the mainnet and testing use

```
forge test --match-contract <CONTRACT-NAME> --rpc-url <ETH_RPC_URL> -vvvv
```

## Disclaimer

Oracles, Fees and Liquidations are not added.
Not in production. So please don't use it.