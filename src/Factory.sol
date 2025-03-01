// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Token} from "./Token.sol";

import {IVC} from "./IVC.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import {console} from "forge-std/console.sol";

contract Factory {
    struct Funding {
        address founder;
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 liqTarget;

        mapping(address => uint) fundersBalances;
        mapping(address => uint) fundersClaimed;
        uint256 totalFund;
        uint256 launchTime;
        Token token;
        bool created;
    }

    IUniswapV2Router02 immutable public router;
    uint256 public deltaLaunch = 30 minutes;
    uint256 public deltaVestingTime = 30 days;

    uint256 public fundingsCount;
    mapping(uint256 => Funding) public fundings;

    constructor (IUniswapV2Router02 _router) {
        router = _router;
        // safe check to ensure that router is deployed
        require(_router.WETH() != address(0), "WETH");
    }

    function fundersBalances(uint256 id, address who) external view returns(uint256) {
        return fundings[id].fundersBalances[who];
    }

    function fundersClaimed(uint256 id, address who) external view returns(uint256) {
        return fundings[id].fundersClaimed[who];
    }

    function createFunding(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 liqTarget
    ) external returns(uint256 id) {
        Funding storage funding = fundings[id = fundingsCount++];
        funding.founder = msg.sender;
        funding.name = name;
        funding.symbol = symbol;
        funding.totalSupply = totalSupply;
        funding.liqTarget = liqTarget;
    }

    function fund(
        uint256 id
    ) external payable {
        Funding storage funding = fundings[id];

        uint256 amount = msg.value;

        if (funding.launchTime != 0) { // 10% less
            require(!funding.created, "created");
            funding.fundersBalances[msg.sender] += amount * 900 / 1000;
            funding.totalFund += msg.value;
            return;
        }

        if (funding.totalFund + amount > funding.liqTarget) {
            amount = funding.liqTarget - funding.totalFund;
            payable(msg.sender).transfer(msg.value - amount);
        }

        funding.fundersBalances[msg.sender] += amount;
        funding.totalFund += amount;

        if (funding.totalFund == funding.liqTarget) {
            funding.launchTime = block.timestamp + deltaLaunch;
        }
    }

    function quitFund(
        uint256 id,
        uint256 amount
    ) external {
        Funding storage funding = fundings[id];

        require(funding.fundersBalances[msg.sender] >= amount, "No user funds");
        require(funding.totalFund < funding.liqTarget, "totalFund");
        require(!funding.created, "created");

        funding.fundersBalances[msg.sender] -= amount;
        funding.totalFund -= amount;
        payable(msg.sender).transfer(amount);
    }

    function createToken(
        uint256 id
    ) public returns(Token token) {
        Funding storage funding = fundings[id];

        require(funding.totalFund >= funding.liqTarget, "No funds");
        require(block.timestamp >= funding.launchTime, "No launch time");

        token = new Token{salt: bytes32(id)}(
            funding.name, 
            funding.symbol,
            funding.totalSupply
        );

        // add liquidity to uni
        token.approve(address(router), funding.totalSupply / 2);
        // @todo use plain add liquidity to avoid issues
        router.addLiquidityETH{
            value: funding.totalFund
        } (
            address(token),
            funding.totalSupply / 2,
            0, // amountTokenMin
            0, // amountETHMin
            address(0xdead),
            block.timestamp
        );

        fundings[id].token = token;
        fundings[id].launchTime = block.timestamp;
        fundings[id].created = true;
    }

    function claimVesting(uint256 id) external {
        Funding storage funding = fundings[id];

        require(funding.created, "Not created");

        uint256 endVesting = funding.launchTime + deltaVestingTime;
        uint256 vestingTime = block.timestamp > endVesting ? endVesting : block.timestamp;
        vestingTime -= funding.launchTime;
        uint256 vestingPercent = vestingTime * 1000 / deltaVestingTime;

        uint256 userPercent = funding.fundersBalances[msg.sender] * 1e18 / funding.totalFund;

        uint256 amount = funding.fundersBalances[msg.sender] * userPercent / (funding.totalSupply / 2);

        amount = amount * vestingPercent / 1000;
        amount = amount - funding.fundersClaimed[msg.sender];

        funding.fundersClaimed[msg.sender] += amount;
        funding.token.transfer(msg.sender, amount);
    }
}
