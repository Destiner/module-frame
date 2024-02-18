// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import {
    CastId,
    FarcasterNetwork,
    FrameActionBody,
    MessageData,
    MessageType
} from "frame-verifier/Encoder.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import "modulekit/Helpers.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { Base64 } from "solady/src/utils/Base64.sol";

import "forge-std/console2.sol";

import { FrameValidator } from "src/FrameValidator.sol";

contract FrameValidatorTest is RhinestoneModuleKit, Test {
    ERC7579ValidatorBase.ValidationData internal constant VALIDATION_FAILED =
        ERC7579ValidatorBase.ValidationData.wrap(1);

    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal aliceAccount;
    FrameValidator internal validator;

    bytes32 internal publicKey = 0x94fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1;

    string BASE_URL = "https://frame-validator.vercel.app/fake-execute/";

    function setUp() public {
        init();

        validator = new FrameValidator(BASE_URL);
        vm.label(address(validator), "FrameValidator");
        assertEq(validator.baseUrl(), BASE_URL);

        aliceAccount = makeAccountInstance("alice");
        vm.deal(address(aliceAccount.account), 10 ether);

        bytes memory data = abi.encode((publicKey));
        aliceAccount.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: data
        });
    }

    function testInstall() public {
        (bytes32 accountPublicKey, uint256 lastFrameTimestamp) =
            validator.accounts(address(aliceAccount.account));
        assertEq(publicKey, accountPublicKey);
    }

    function testEthTransfer() public {
        // FC message:
        // 0a9101080d109b3e18cdef842f2001820181010a6268747470733a2f2f6672616d652d76616c696461746f722e76657263656c2e6170702f66616b652d657865637574652f33313333372f7567356c48456162336e5544776c3876574e4f7730302d73397665627555564b4b4b77416136694a7732633d10011a19089b3e1214000000000000000000000000000000000000000112148b556cddc4c97208aea4b49e0b54327b20fae469180122405649d36d30dec4d7338f412f40f179183b6d1890c98102c5a6bc713159c2c5471e24994667d59168a3b3b2aca7b7f5cadb41be5d75f4f356f59a30567075d40b2801322094fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        string memory url = string.concat(
            BASE_URL,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x5649d36d30dec4d7338f412f40f179183b6d1890c98102c5a6bc713159c2c547,
            signature_s: 0x1e24994667d59168a3b3b2aca7b7f5cadb41be5d75f4f356f59a30567075d40b,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_645_965,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertNotEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testErc20Transfer() public {
        // FC message:
        // 0a9101080d109b3e18f48e852f2001820181010a6268747470733a2f2f6672616d652d76616c696461746f722e76657263656c2e6170702f66616b652d657865637574652f33313333372f596c4e2d5372743066396b694e723248617a4e346e353435383361666e6d4f34635a577a737a32496b584d3d10011a19089b3e1214000000000000000000000000000000000000000112143f967a00d36d29b7bc589d454c55a3c2af8dddc9180122407de35c327c9abaca540e4f02cbc2328cfb25bff4556b1079e4538dfb9f6036ca9ea5d75606366f43db6ba1a8dcdc90da1a30723fe6ccae93f825b0e4eb4e30012801322094fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1
        address dai = makeAddr("dai");
        uint256 value = 0 ether;
        address recipient = makeAddr("recipient");
        uint256 amount = 123 ether;
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);
        bytes4 methodId = bytes4(keccak256("transfer(address,uint256)"));
        bytes memory callData = abi.encodeWithSelector(methodId, recipient, amount);

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: dai,
            value: value,
            callData: callData,
            txValidator: address(validator)
        });
        string memory url = string.concat(
            BASE_URL,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );

        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x7de35c327c9abaca540e4f02cbc2328cfb25bff4556b1079e4538dfb9f6036ca,
            signature_s: 0x9ea5d75606366f43db6ba1a8dcdc90da1a30723fe6ccae93f825b0e4eb4e3001,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_649_972,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertNotEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testInvalidOwner() public {
        // TODO test by signing the message with a different key
    }

    function testInvalidSignature() public {
        // FC message:
        // 0a9101080d109b3e18cdef842f2001820181010a6268747470733a2f2f6672616d652d76616c696461746f722e76657263656c2e6170702f66616b652d657865637574652f33313333372f7567356c48456162336e5544776c3876574e4f7730302d73397665627555564b4b4b77416136694a7732633d10011a19089b3e1214000000000000000000000000000000000000000112148b556cddc4c97208aea4b49e0b54327b20fae469180122405649d36d30dec4d7338f412f40f179183b6d1890c98102c5a6bc713159c2c5471e24994667d59168a3b3b2aca7b7f5cadb41be5d75f4f356f59a30567075d40b2801322094fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1
        // Same as testEthTransfer but with an off-by-one error in the signature
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        string memory url = string.concat(
            BASE_URL,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x5649d36d30dec4d7338f412f40f179183b6d1890c98102c5a6bc713159c2c546,
            signature_s: 0x1e24994667d59168a3b3b2aca7b7f5cadb41be5d75f4f356f59a30567075d40b,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_645_965,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testUrlInvalidBaseUrl() public {
        // FC message:
        // 0a9b01080d109b3e18e5ef842f200182018b010a6c68747470733a2f2f6d616c6963696f75732d6672616d652d76616c696461746f722e76657263656c2e6170702f66616b652d657865637574652f33313333372f7567356c48456162336e5544776c3876574e4f7730302d73397665627555564b4b4b77416136694a7732633d10011a19089b3e121400000000000000000000000000000000000000011214a1a33483bac9f880dbbf7ac7d28d3abf8d6a6cc6180122403cb534a97511e05bea338a638f1cbb4010c5dd54729ceea10ad73038eefc036795b1bcaa9b2e356cb468e32855bfbcf5758a02cbca72e4acf768ccfc97ddef0c2801322094fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1
        // Same as testEthTransfer but with a malicious base URL
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        string memory url = string.concat(
            "https://malicious-frame-validator.vercel.app/fake-execute/",
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x3cb534a97511e05bea338a638f1cbb4010c5dd54729ceea10ad73038eefc0367,
            signature_s: 0x95b1bcaa9b2e356cb468e32855bfbcf5758a02cbca72e4acf768ccfc97ddef0c,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_645_989,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testUrlInvalidChain() public {
        // FC message:
        // 0a9401080d109b3e18dcef842f2001820184010a6568747470733a2f2f6672616d652d76616c696461746f722e76657263656c2e6170702f66616b652d657865637574652f31313135353131312f7567356c48456162336e5544776c3876574e4f7730302d73397665627555564b4b4b77416136694a7732633d10011a19089b3e1214000000000000000000000000000000000000000112142b758d02694b4133c53c7fe5c50da0c62a957f6c1801224026903ac950aaad4adbcf29cbcaf42a40f8dfb644e675cae01752642e562eecf79eea3bb683c043d6e6e90a7ce53045b6e36bfb272c13382d511ab47f72978a042801322094fec6dd277668cf5db24b408b79f91aa987fb20e4778fdd2bc94375f7f361f1
        // Same as testEthTransfer but with an invalid chain ID
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        string memory url = string.concat(
            BASE_URL,
            "11155111",
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x26903ac950aaad4adbcf29cbcaf42a40f8dfb644e675cae01752642e562eecf7,
            signature_s: 0x9eea3bb683c043d6e6e90a7ce53045b6e36bfb272c13382d511ab47f72978a04,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_645_980,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testUrlInvalidCalldata() public {
        // Same as testEthTransfer but an invalid calldata in the URL
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        bytes memory callDataCopy = abi.encodePacked(userOpData.userOp.callData);
        // XOR the first byte with 0xFF to toggle all its bits
        callDataCopy[0] = bytes1(uint8(callDataCopy[0]) ^ 0xFF);
        string memory url = string.concat(
            BASE_URL,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(callDataCopy)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0xea6a3926da8badb1783967de6189e3158309e47507a68261c59e04d3777b09e8,
            signature_s: 0xa41840f3c003f8003bf3e682698262035e28e48d37cfeb24cac71a05438aba0a,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_652_172,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }

    function testReplayAttack() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;

        UserOpData memory userOpData = aliceAccount.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        string memory url = string.concat(
            BASE_URL,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(userOpData.userOp.callData)), true)
        );
        FrameValidator.FrameUserOpSignature memory frameStruct = FrameValidator.FrameUserOpSignature({
            signature_r: 0x5649d36d30dec4d7338f412f40f179183b6d1890c98102c5a6bc713159c2c547,
            signature_s: 0x1e24994667d59168a3b3b2aca7b7f5cadb41be5d75f4f356f59a30567075d40b,
            messageData: MessageData({
                type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
                fid: 7963,
                timestamp: 98_645_965,
                network: FarcasterNetwork.FARCASTER_NETWORK_MAINNET,
                frame_action_body: FrameActionBody({
                    url: bytes(url),
                    button_index: 1,
                    cast_id: CastId({ fid: 7963, hash: hex"0000000000000000000000000000000000000001" }),
                    input_text: ""
                })
            })
        });
        bytes memory frameStructData = abi.encode(frameStruct);
        userOpData.userOp.signature = abi.encode(frameStructData, address(validator));
        ERC7579ValidatorBase.ValidationData validationResult =
            validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertNotEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );

        // Replay the same UserOp
        validationResult = validator.validateUserOp(userOpData.userOp, userOpData.userOpHash);
        assertEq(
            ERC7579ValidatorBase.ValidationData.unwrap(validationResult),
            ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_FAILED)
        );
    }
}
