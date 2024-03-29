// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MessageData, FarcasterNetwork } from "frame-verifier/Encoder.sol";
import { FrameVerifier } from "frame-verifier/FrameVerifier.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { UserOperation } from "account-abstraction-v0.6/interfaces/UserOperation.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "solady/src/utils/Base64.sol";

import "forge-std/console2.sol";

contract FrameValidator is ERC7579ValidatorBase {
    error DuplicateAccount();

    // The trusted URL to validate the transaction
    // Everything coming from this URL is considered valid
    string public baseUrl;
    // The valid farcaster network
    FarcasterNetwork public farcasterNetwork;

    struct FrameUserOpSignature {
        bytes32 signatureR;
        bytes32 signatureS;
        MessageData messageData;
    }

    mapping(address account => bytes32 publicKey) public accounts;
    mapping(bytes32 publicKey => uint256 lastFrameTimestamp) public nonces;

    constructor(string memory _baseUrl, FarcasterNetwork _farcasterNetwork) {
        baseUrl = _baseUrl;
        farcasterNetwork = _farcasterNetwork;
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
        if (accounts[msg.sender] != bytes32(0)) {
            revert DuplicateAccount();
        }
        accounts[msg.sender] = publicKey;
    }

    /* De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata) external override {
        delete accounts[msg.sender];
    }

    /*
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return accounts[smartAccount] != bytes32(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates PackedUserOperation
     * @param userOp PackedUserOperation to be validated.
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - 0 if the signature is valid
     *  - 1 if the signature is invalid
     *  - <20-byte> aggregatorOrSigFail, <6-byte> validUntil and <6-byte> validAfter (see ERC-4337
     * for more details)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32
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
        bytes32
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
        FrameUserOpSignature memory frameStruct = abi.decode(signature, (FrameUserOpSignature));
        // Verify signature
        if (
            !FrameVerifier.verifyMessageData(
                accounts[sender],
                frameStruct.signatureR,
                frameStruct.signatureS,
                frameStruct.messageData
            )
        ) {
            return VALIDATION_FAILED;
        }
        // Make sure
        if (frameStruct.messageData.network != farcasterNetwork) {
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
        if (frameStruct.messageData.timestamp <= nonces[accounts[sender]]) {
            return VALIDATION_FAILED;
        }
        nonces[accounts[sender]] = frameStruct.messageData.timestamp;
        return ValidationData.wrap(0);
    }

    /**
     * Validates an ERC-1271 signature
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - EIP1271_SUCCESS if the signature is valid
     *  - EIP1271_FAILED if the signature is invalid
     */
    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
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
}
