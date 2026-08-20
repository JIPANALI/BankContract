// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script,console} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";


contract BankScript is Script{
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner=vm.addr(deployerPrivateKey);

        Bank bank = new Bank(owner);
        console.log("Bank deployed at address:", address(bank));
        console.log("Owner address:", owner);

        vm.stopBroadcast();
    }
}