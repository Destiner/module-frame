// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    RhinestoneAccount
} from "modulekit/ModuleKit.sol";
import { HookTemplate } from "src/HookTemplate.sol";

contract HookTemplateTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    RhinestoneAccount internal instance;
    HookTemplate internal hook;

    function setUp() public {
        init();

        // Create the hook
        hook = new HookTemplate();
        vm.label(address(hook), "HookTemplate");

        // Create the account and install the hook
        instance = makeRhinestoneAccount("HookTemplate");
        vm.deal(address(instance.account), 10 ether);
        instance.installHook(address(hook), "");
    }

    function testExec() public {
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Execute the call
        instance.exec({ target: target, value: value, callData: "" });

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }
}
