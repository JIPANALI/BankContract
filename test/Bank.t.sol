// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event Transferred(address indexed from, address indexed to, uint256 amount);
    event StatusChanged(Bank.Status newStatus);

    function setUp() public {
        bank = new Bank(owner);
        vm.deal(alice, 10 ether); //this is for the deposit to his own wallet not to the contract
        vm.deal(bob, 10 ether);
    }

    function test_InitialState() public view {
        assertEq(bank.owner(), owner);
        assertEq(bank.totalDeposits(), 0);
        assertEq(uint256(bank.status()), uint256(Bank.Status.Active));
    }

    function test_Deposit() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}(); //this deposit to contract account
        assertEq(bank.balanceOf(alice), 1 ether);
        assertEq(bank.totalDeposits(), 1 ether);
        assertEq(bank.totalAccounts(), 1);
    }

    function test_DeoositTwiceNoDuplicateInList() public {
        vm.startPrank(alice);
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 2 ether}();
        vm.stopPrank();

        assertEq(bank.balanceOf(alice), 3 ether);
        assertEq(bank.totalDeposits(), 3 ether);
        assertEq(bank.totalAccounts(), 1);
    }

    function test_DepositEmitsEvent() public {
        vm.expectEmit(true, false, false, true); //here 1 index,remaing for the data if 4th is 1,// if two index then it will be (true,true,false,true)//for three index (true,true,true,true)
        emit Deposited(alice, 1 ether, 1 ether);

        vm.prank(alice);
        bank.deposit{value: 1 ether}();
    }

    function testRevertWhenDepositZero() public {
        vm.prank(alice);
        vm.expectRevert(Bank.ZeroAmount.selector);
        bank.deposit{value: 0}();
    }

    function test_DepositUpdatesLastDeposit() public {
        vm.warp(12345); //set the block.timestamp to 12345
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        (, uint256 lastDeposit, bool exists) = bank.getAccount(alice);
        assertEq(lastDeposit, 12345);
        assertTrue(exists);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        bank.deposit{value: 2 ether}();
        bank.withdraw(1 ether);
        vm.stopPrank();

        assertEq(bank.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    function test_RevertWhen_WithdrawZero() public {
        vm.startPrank(alice);
        bank.deposit{value: 1 ether}();
        vm.expectRevert(Bank.ZeroAmount.selector);
        bank.withdraw(0);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawOverBalance() public {
        vm.startPrank(alice);
        bank.deposit{value: 1 ether}();
        vm.expectRevert(
            abi.encodeWithSelector(
                Bank.InsufficientBalance.selector,
                2 ether,
                1 ether
            ) //when error has parameter then do like this
        );
        bank.withdraw(2 ether);
        vm.stopPrank();
    }

    ///transfer
    function test_Transfer() public {
        vm.startPrank(alice);
        bank.deposit{value: 3 ether}();
        bank.transfer(bob, 1 ether);
        vm.stopPrank();
        assertEq(bank.balanceOf(alice), 2 ether);
        assertEq(bank.balanceOf(bob), 1 ether);
    }

    function test_TransferEmitEvent() public {
        vm.startPrank(alice);
        bank.deposit{value: 3 ether}();
        vm.expectEmit(true, true, false, true);
        emit Transferred(alice, bob, 1 ether);
        bank.transfer(bob, 1 ether);
        vm.stopPrank();
    }

    function test_RevertWhenTransferTooMuch() public {
        vm.startPrank(alice);
        bank.deposit{value: 3 ether}();
        vm.expectRevert(
            abi.encodeWithSelector(
                Bank.InsufficientBalance.selector,
                4 ether,
                3 ether
            )
        );
        bank.transfer(bob, 4 ether);
        vm.stopPrank();
    }

    function test_RevertWhenTransferZero() public {
        vm.startPrank(alice);
        bank.deposit{value: 3 ether}();
        vm.expectRevert(Bank.ZeroAmount.selector);
        bank.transfer(bob, 0);
        vm.stopPrank();
    }

    // Admin functions

    function testOwnerCanSetStatus() public {
        vm.prank(owner);
        bank.setStatus(Bank.Status.Frozen);
        assertEq(uint256(bank.status()), uint256(Bank.Status.Frozen));
    }

    function test_RevertWhenNonOwnerSetStatus() public {
        vm.prank(alice);
        vm.expectRevert(Bank.NotOwner.selector);
        bank.setStatus(Bank.Status.Frozen);
    }

    function test_SetStatusEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit StatusChanged(Bank.Status.Frozen);
        bank.setStatus(Bank.Status.Frozen);
    }

    function test_RevertWhen_DepositWhileFrozen() public {
        vm.prank(owner);
        bank.setStatus(Bank.Status.Frozen);

        vm.prank(alice);
        vm.expectRevert(Bank.BankFrozen.selector);
        bank.deposit{value: 1 ether}();
    }

    function test_RevertWhen_WithdrawWhileFrozen() public {
        //first deposit
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        //then freeze
        vm.prank(owner);
        bank.setStatus(Bank.Status.Frozen);

        //then withdraw
        vm.prank(alice);
        vm.expectRevert(Bank.BankFrozen.selector);
        bank.withdraw(1 ether);
    }

    //fallback and recieve
    function test_ReceiveTriggersDeposit() public {
        vm.prank(alice);
        (bool ok, ) = address(bank).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(bank.balanceOf(alice), 1 ether);
    }

    function test_FallbackTriggersDeposit() public {
        vm.prank(alice);
        (bool ok, ) = address(bank).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(bank.balanceOf(alice), 1 ether);
    }

function testRevert_WhenFallback() public {
        vm.prank(alice);
        (bool ok, ) = address(bank).call{value: 1 ether}(hex"00");
        assertFalse(ok);
    }

    function test_ComputeFee() public view {
        assertEq(bank.computeFee(100 ether, 100), 1 ether);
    }

    // Fuzz test — Foundry runs this with many random inputs
    function testFuzz_DepositWithdraw(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(alice, amount);// replace the wallet balance of the alice which was done in setUp  to that amount
        vm.startPrank(alice);

        bank.deposit{value: amount}();
        assertEq(bank.balanceOf(alice), amount);

        bank.withdraw(amount);

        assertEq(bank.balanceOf(alice), 0);
        vm.stopPrank();
    }


}
