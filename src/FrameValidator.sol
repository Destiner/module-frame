// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { EncodedModuleTypes } from "erc7579/lib/ModuleTypeLib.sol";
import { MessageData } from "frame-verifier/Encoder.sol";
import { FrameVerifier } from "frame-verifier/FrameVerifier.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { UserOperation } from "account-abstraction-v0.6/interfaces/UserOperation.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { Base64 } from "solady/src/utils/Base64.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

import "forge-std/console2.sol";

contract FrameValidator is ERC7579ValidatorBase {
    error DuplicateAccount();
    error DuplicatePublicKey();

    // The trusted URL to validate the transaction
    // Everything coming from this URL is considered valid
    string public baseUrl;

    struct FrameUserOpSignature {
        bytes32 signature_r;
        bytes32 signature_s;
        MessageData messageData;
    }

    struct AccountData {
        bytes32 publicKey;
        uint256 lastFrameTimestamp;
    }

    mapping(address account => AccountData data) public accounts;
    mapping(bytes32 publicKey => address account) public keys;

    constructor(string memory _baseUrl) {
        baseUrl = _baseUrl;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /* Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) public override {
        if (data.length == 0) return;
        bytes32 publicKey = abi.decode(data, (bytes32));
        if (accounts[msg.sender].publicKey != bytes32(0)) {
            revert DuplicateAccount();
        }
        if (keys[publicKey] != address(0)) {
            revert DuplicatePublicKey();
        }
        accounts[msg.sender] = AccountData(publicKey, 0);
        keys[publicKey] = msg.sender;
    }

    // Compatible with Biconomy Account V2
    function onModuleInstall(bytes calldata data) external returns (address module) {
        onInstall(data);
        return address(this);
    }

    /* De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata) external override {
        delete keys[accounts[msg.sender].publicKey];
        delete accounts[msg.sender];
    }

    /*
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return accounts[smartAccount].publicKey != bytes32(0)
            && keys[accounts[smartAccount].publicKey] == smartAccount;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates PackedUserOperation
     * @param userOp PackedUserOperation to be validated.
     * @param userOpHash Hash of the PackedUserOperation to be validated.
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - 0 if the signature is valid
     *  - 1 if the signature is invalid
     *  - <20-byte> aggregatorOrSigFail, <6-byte> validUntil and <6-byte> validAfter (see ERC-4337
     * for more details)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        return _validateUserOp(userOp.sender, userOp.signature, userOp.callData);
    }

    // Compatible with Entrypoint 0.6
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (ValidationData)
    {
        return _validateUserOp(userOp.sender, userOp.signature, userOp.callData);
    }

    function _validateUserOp(
        address sender,
        bytes calldata signature,
        bytes calldata callData
    )
        internal
        returns (ValidationData)
    {
        (bytes memory frameStructData,) = abi.decode(signature, (bytes, address));
        FrameUserOpSignature memory frameStruct =
            abi.decode(frameStructData, (FrameUserOpSignature));
        // Verify signature
        if (
            !FrameVerifier.verifyMessageData(
                accounts[sender].publicKey,
                frameStruct.signature_r,
                frameStruct.signature_s,
                frameStruct.messageData
            )
        ) {
            return VALIDATION_FAILED;
        }
        // Verify URL-decoded calldata
        string memory expectedUrl = string.concat(
            baseUrl,
            Strings.toString(block.chainid),
            "/",
            Base64.encode(abi.encodePacked(keccak256(callData)), true)
        );
        if (!Strings.equal(string(frameStruct.messageData.frame_action_body.url), expectedUrl)) {
            return VALIDATION_FAILED;
        }
        // Verify timestamp to protect against replay attacks
        if (frameStruct.messageData.timestamp <= accounts[sender].lastFrameTimestamp) {
            return VALIDATION_FAILED;
        }
        accounts[sender].lastFrameTimestamp = frameStruct.messageData.timestamp;
        return ValidationData.wrap(0);
    }

    /**
     * Validates an ERC-1271 signature
     * @param sender The sender of the ERC-1271 call to the account
     * @param hash The hash of the message
     * @param signature The signature of the message
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - EIP1271_SUCCESS if the signature is valid
     *  - EIP1271_FAILED if the signature is invalid
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sigValidationResult)
    {
        // TODO
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "FrameValidator";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /*
     * Check if the module is of a certain type
     * @param typeID The type ID to check
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    /**
     * Get the module types
     * @return moduleTypes The bit-encoded module types
     */
    function getModuleTypes() external view returns (EncodedModuleTypes) { }
}
