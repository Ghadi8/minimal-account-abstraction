// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessagehashUtils.sol";

import {Script} from "forge-std/Script.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate the unsigned user operation
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory packedUserOperation = _generateUserOperation(callData, minimalAccount, nonce);

        // 2. Get the UserOpHash
        bytes32 userOpHash = IEntryPoint(config.entrypoint).getUserOpHash(packedUserOperation);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. Sign the UserOpHash
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_ACCOUNT = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_ACCOUNT, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        packedUserOperation.signature = abi.encodePacked(r, s, v);

        return packedUserOperation;
    }

    function _generateUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(verificationGasLimit) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
