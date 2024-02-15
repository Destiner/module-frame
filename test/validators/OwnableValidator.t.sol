// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import "modulekit/Helpers.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, ModuleKitUserOp, RhinestoneAccount, UserOpData} from "modulekit/ModuleKit.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";

import "forge-std/console2.sol";

import {OwnableValidator} from "src/OwnableValidator.sol";

contract OwnableValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    RhinestoneAccount internal instance;
    OwnableValidator internal validator;

    function setUp() public {
        init();

        // Create the validator
        validator = new OwnableValidator();
        vm.label(address(validator), "OwnableValidator");

        // Create the account and install the validator
        (address owner, ) = makeAddrAndKey("owner");
        instance = makeRhinestoneAccount("OwnableValidator");
        vm.deal(address(instance.account), 10 ether);

        bytes memory data = abi.encode((address(owner)));
        instance.installValidator(address(validator), data);
    }

    function testInstall() public {
        // Check if the validator is properly installed
        (address owner, ) = makeAddrAndKey("owner");
        assertEq(validator.owners(address(instance.account)), address(owner));
    }

    function testExec() public {
        (, uint256 key) = makeAddrAndKey("owner");
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = target.balance;

        // Get the UserOp data (UserOperation and UserOperationHash)
        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        bytes memory signature = ecdsaSign(
            key,
            ECDSA.toEthSignedMessageHash(userOpData.userOpHash)
        );

        // Set the signature
        userOpData.userOp.signature = signature;

        // Execute the UserOp
        userOpData.execUserOps();

        // Check if the balance of the target has increased
        assertEq(target.balance, prevBalance + value);
    }
}
