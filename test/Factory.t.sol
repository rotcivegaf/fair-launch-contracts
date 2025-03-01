// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";

import {Factory} from "../src/Factory.sol";
import {Token} from "../src/Token.sol";

contract FactoryTest is Test {
    Factory factory;

    function setUp() public {
        vm.selectFork(vm.createFork("https://ethereum-rpc.publicnode.com"));

        IUniswapV2Router02 router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        factory = new Factory(
            router
        );
    }

    function test_createFunding() public {
        uint256 id = factory.createFunding(
            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        // checks
        (   
            address founder,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token,
            bool created
        ) = factory.fundings(id);

        assert(keccak256(abi.encode(name)) == keccak256(abi.encode("test")));
        assert(keccak256(abi.encode(symbol)) == keccak256(abi.encode("TEST")));
        assert(totalSupply == 100 ether);
        assert(liqTarget == 2.5 ether);
        assert(totalFund == 0);
        assert(launchTime == 0);
        assert(token == Token(address(0)));
        assert(created == false);
    }


    function test_fund() public {
        uint256 id = factory.createFunding(
            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        factory.fund{value: 1 ether}(id);

        // checks
        (
            ,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token,
            bool created
        ) = factory.fundings(id);

        assert(factory.fundersBalances(id, address(this)) == 1 ether);

        assert(keccak256(abi.encode(name)) == keccak256(abi.encode("test")));
        assert(keccak256(abi.encode(symbol)) == keccak256(abi.encode("TEST")));
        assert(totalSupply == 100 ether);
        assert(liqTarget == 2.5 ether);
        assert(totalFund == 1 ether);
        assert(launchTime == 0);
        assert(token == Token(address(0)));
        assert(created == false);
    }

    function test_fundFull() public {
        uint256 id = factory.createFunding(

            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        factory.fund{value: 1 ether}(id);
        factory.fund{value: 3 ether}(id);

        // checks
        (
            ,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token,
            bool created
        ) = factory.fundings(id);

        assert(factory.fundersBalances(id, address(this)) == 2.5 ether);
            
        assert(totalFund == 2.5 ether);
        assert(launchTime == block.timestamp + factory.deltaLaunch());
        assert(token == Token(address(0)));
        assert(created == false);
    }

    function test_fundAfterFull() public {
        uint256 id = factory.createFunding(
            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        factory.fund{value: 3 ether}(id);
        uint256 prevBal = factory.fundersBalances(id, address(this));
        
        factory.fund{value: 10 ether}(id);

        // checks
        (
            ,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token,
            bool created
        ) = factory.fundings(id);

        assert(factory.fundersBalances(id, address(this)) == prevBal + 9 ether);
            
        assert(totalFund == prevBal + 10 ether);
        assert(launchTime == block.timestamp + factory.deltaLaunch());
        assert(token == Token(address(0)));
        assert(created == false);
    }

    function test_quitFund() public {
        uint256 id = factory.createFunding(
            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        factory.fund{value: 2 ether}(id);

        factory.quitFund(id, 0.5 ether);

        // checks
        (
            ,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token,
            bool created
        ) = factory.fundings(id);

        assert(factory.fundersBalances(id, address(this)) == 1.5 ether);

        assert(totalFund == 1.5 ether);
        assert(launchTime == 0);
        assert(token == Token(address(0)));
        assert(created == false);
    }

    function test_createToken() public {
        address userA = address(88888888);
        vm.deal(userA, 1.5 ether);
        address userB = address(99999999);
        vm.deal(userB, 2 ether);

        uint256 id = factory.createFunding(
            "test",
            "TEST",
            100 ether,
            2.5 ether
        );

        vm.prank(userA);
        factory.fund{value: 1.5 ether}(id);

        vm.prank(userB);
        factory.fund{value: 1 ether}(id);
        vm.prank(userB);
        factory.fund{value: 1 ether}(id);

        vm.warp(block.timestamp + factory.deltaLaunch());

        Token token = factory.createToken(id);

        // checks
        (
            ,
            string memory name,
            string memory symbol,
            uint256 totalSupply,
            uint256 liqTarget,
            uint256 totalFund,
            uint256 launchTime,
            Token token2,
            bool created
        ) = factory.fundings(id);

        assert(factory.fundersBalances(id, userA) == 1.5 ether);
        assert(factory.fundersBalances(id, userB) == 1.9 ether);

        assert(totalFund == 1.5 ether + 2 ether);
        assert(launchTime == block.timestamp);
        assert(token == token2);
        assert(created == true);

        assert(token.balanceOf(address(factory)) == totalSupply / 2);
        IUniswapV2Factory uniFactory = IUniswapV2Factory(factory.router().factory());
        address pair = uniFactory.getPair(factory.router().WETH(), address(token));
        assert(token.balanceOf(pair) == totalSupply / 2);
        
        assert(Token(factory.router().WETH()).balanceOf(pair) == totalFund);
    }

    function test_claimVesting50PercentAnd100() public {
        address userA = address(88888888);
        vm.deal(userA, 2 ether);
        address userB = address(99999999);
        vm.deal(userB, 2 ether);

        uint256 id = factory.createFunding(
            "test",
            "TEST",
            4 ether,
            4 ether
        );

        vm.prank(userA);
        factory.fund{value: 2 ether}(id);

        vm.prank(userB);
        factory.fund{value: 2 ether}(id);
        vm.warp(block.timestamp + factory.deltaLaunch());
        Token token = factory.createToken(id);

        vm.warp(block.timestamp + factory.deltaLaunch() + (factory.deltaVestingTime() / 2));
        
        // User A
        vm.prank(userA);
        factory.claimVesting(id);

        // checks
        assert(token.balanceOf(userA) == 0.25 ether);
        assert(factory.fundersClaimed(id, userA) == 0.25 ether);

        // User B
        vm.prank(userB);
        factory.claimVesting(id);

        // checks
        assert(token.balanceOf(userB) == 0.25 ether);
        assert(factory.fundersClaimed(id, userB) == 0.25 ether);

        vm.warp(block.timestamp + factory.deltaLaunch() + factory.deltaVestingTime());

        // User A
        vm.prank(userA);
        factory.claimVesting(id);

        // checks
        assert(token.balanceOf(userA) == 0.5 ether);
        assert(factory.fundersClaimed(id, userA) == 0.5 ether);

        // User B
        vm.prank(userB);
        factory.claimVesting(id);

        // checks
        assert(token.balanceOf(userB) == 0.5 ether);
        assert(factory.fundersClaimed(id, userB) == 0.5 ether);
    }

    receive() payable external{}
}
