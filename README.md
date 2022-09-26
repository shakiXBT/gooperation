# Gooperation

The legendary gobblers belong to the people

## Features

The contract has two stages:

Before auction win:
- users can deposit multiple Gobblers in the Gooperation contract
- users can withdraw their Gobblers

Once the legendary Gobbler auction starts, anyone can call the `mintLegendaryGobbler`

After auction win:
- users can claim their goo share out of the total goo held by the contract, proportional to the sum of all their burned gobblers multipliers
- users retain ownership of a fraction of their legendary

## WIP
- users ownership of a fraction of the legendary is calculated with `gobblersBurnedByUser / totalGobblersBurned`, but could also be `total multiplier of gobblers burned by user / total multiplier of all gobblers burned`, to prevent people to burn low multiplier gobblers and be rewarded in the same way as someone that burns a high multiplier gobbler. 
- each contract deploy can only own one legendary Gobbler
- currently the legendary Gobbler will be stuck inside the Gooperation contract, endlessly producing Goo. Still need to decide what to do with it (auction system? actually fractionalize it?)
- currently the users that have burned their Gobblers through Gooperation to acquire a Legendary Gobbler can only claim their share of Goo once.
- handling scenarios where Legendary auction is won after the price goes down from starting price.

## TODO dev:
- deploy scripts

## Usage

Make sure you have [Foundry](https://github.com/foundry-rs/foundry) installed on your machine

### Setup

```sh
git clone https://github.com/shakiXBT/gooperation.git
cd gooperation
forge install 
```

### Build

```sh
forge build
```

### Run Tests

```sh
forge test
```