// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployMinimalAccount} from "../../script/DeployMinimalAccount.s.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessagehashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimalAccount deployMinimalAccount;
    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address USER = makeAddr("user");

    function setUp() public {
        deployMinimalAccount = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployMinimalAccount.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assert(usdc.balanceOf(address(minimalAccount)) == 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), 100);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        assert(usdc.balanceOf(address(minimalAccount)) == 100);
    }

    function testNonOwnerOrEntryPointCannotExecuteCommands() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), 100);

        vm.prank(USER);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedUserOps() public {
        assert(usdc.balanceOf(address(minimalAccount)) == 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), 100);

        bytes memory executeData = abi.encodeWithSignature("execute(address,uint256,bytes)", dest, value, functionData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory packedUserOperation =
            sendPackedUserOp.generateSignedUserOperation(executeData, config, address(minimalAccount));

        bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOperation);

        address signer = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOperation.signature);

        assert(signer == config.account);
    }

    function testValidationOfUserOps() public {
        assert(usdc.balanceOf(address(minimalAccount)) == 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), 100);

        bytes memory executeData = abi.encodeWithSignature("execute(address,uint256,bytes)", dest, value, functionData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory packedUserOperation =
            sendPackedUserOp.generateSignedUserOperation(executeData, config, address(minimalAccount));

        bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOperation);

        uint256 missingAccountFuns = 1e18;

        vm.startPrank(minimalAccount.getEntryPoint());
        uint256 validationData =
            minimalAccount.validateUserOp(packedUserOperation, userOperationHash, missingAccountFuns);

        vm.stopPrank();

        assertEq(validationData, 0);
    }

    function testEntrypointCanExecuteCommands() public {
        assert(usdc.balanceOf(address(minimalAccount)) == 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("mint(address,uint256)", address(minimalAccount), 100);

        bytes memory executeData = abi.encodeWithSignature("execute(address,uint256,bytes)", dest, value, functionData);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        PackedUserOperation memory packedUserOperation =
            sendPackedUserOp.generateSignedUserOperation(executeData, config, address(minimalAccount));

        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOperation;

        vm.prank(USER);
        IEntryPoint(config.entryPoint).handleOps(ops, payable(USER));

        assertEq(usdc.balanceOf(address(minimalAccount)), 100);
    }
}
