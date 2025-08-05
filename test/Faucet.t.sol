// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Faucet} from "../src/Faucet.sol";
import {Token} from "../src/Token.sol";

contract TestFaucet is Test {
    Faucet public faucet;
    Token public token;

    event Distributed(address indexed to, uint256 indexed amount);

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    address public OWNER = makeAddr("owner");

    uint256 public constant DISTRIBUTION_TOKEN = 100 * 10 ** 18;
    uint256 public constant INITIAL_FAUCET_BALANCE = 1000 ether;

    function setUp() public {
        vm.startPrank(OWNER);
        token = new Token();
        faucet = new Faucet(address(token), OWNER);
        token.transferTo(address(faucet), INITIAL_FAUCET_BALANCE);
        vm.stopPrank();

        // Set initial timestamp for consistent testing
        vm.warp(86400);
    }

    function testDistribution() public {
        uint256 initialBalance = token.balanceOf(USER);
        uint256 initialTimestamp = block.timestamp;

        vm.prank(USER);
        faucet.distribution();

        assertEq(
            token.balanceOf(USER),
            initialBalance + DISTRIBUTION_TOKEN,
            "Token transfer failed"
        );

        assertEq(
            faucet.distributionAddresses(USER),
            DISTRIBUTION_TOKEN,
            "Distribution record failed"
        );

        assertApproxEqAbs(
            faucet.lastDistribute(USER),
            initialTimestamp,
            2,
            "Timestamp record failed"
        );

        vm.prank(USER);
        vm.expectRevert(Faucet.CooldownNotExpired.selector); // Fixed: Changed expected error to CooldownNotExpired
        faucet.distribution();
    }

    function testDistributionWithSetAmount() public {
        uint256 customAmount = 500;
        uint256 expectedAmount = customAmount * 10 ** 18;

        vm.prank(OWNER);
        faucet.setDistributionAmount(customAmount);

        vm.prank(USER);
        faucet.distribution();

        assertEq(
            token.balanceOf(USER),
            expectedAmount,
            "Custom amount distribution failed"
        );
    }

    function testInsufficientFaucetBalance() public {
        deal(address(token), address(faucet), 0);
        vm.prank(USER);
        vm.expectRevert(Faucet.InsufficientFaucetBalance.selector);
        faucet.distribution();
    }

    function testCooldownPeriod() public {
        vm.prank(USER);
        faucet.distribution();

        vm.prank(USER);
        vm.expectRevert(Faucet.CooldownNotExpired.selector);
        faucet.distribution();

        vm.warp(block.timestamp + 86399 seconds);
        vm.prank(USER);
        vm.expectRevert(Faucet.CooldownNotExpired.selector);
        faucet.distribution();

        vm.warp(block.timestamp + 2 seconds);
        vm.prank(USER);
        faucet.distribution();

        assertEq(
            token.balanceOf(USER),
            DISTRIBUTION_TOKEN * 2,
            "Should allow second distribution after cooldown"
        );
    }

    function testDistributionEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Distributed(USER, DISTRIBUTION_TOKEN);
        vm.prank(USER);
        faucet.distribution();
    }

    function testMultipleUsers() public {
        vm.prank(USER);
        faucet.distribution();

        vm.prank(USER2);
        faucet.distribution();

        assertEq(token.balanceOf(USER), DISTRIBUTION_TOKEN);
        assertEq(token.balanceOf(USER2), DISTRIBUTION_TOKEN);
    }

    function testOnlyOwnerFunctions() public {
        bytes4 selector = bytes4(
            keccak256("OwnableUnauthorizedAccount(address)")
        );

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(selector, USER));
        faucet.setDistributionAmount(200);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(selector, USER));
        faucet.withdrawTokens(100 ether);
    }

    function testWithdrawTokens() public {
        uint256 withdrawAmount = 100 ether;
        uint256 initialBalance = token.balanceOf(OWNER);

        vm.prank(OWNER);
        faucet.withdrawTokens(withdrawAmount);

        assertEq(
            token.balanceOf(OWNER),
            initialBalance + withdrawAmount,
            "Withdrawal failed"
        );
    }

    function testCanClaim() public {
        assertTrue(faucet.canClaim(USER), "Fresh user should be able to claim");

        vm.prank(USER);
        faucet.distribution();

        assertFalse(
            faucet.canClaim(USER),
            "User should not be able to claim during cooldown period"
        );

        vm.warp(block.timestamp + 86401 seconds);
        assertTrue(
            faucet.canClaim(USER),
            "User should be able to claim after cooldown expires"
        );
    }

    function testGetClaimTime() public {
        assertEq(
            faucet.getClaimTime(USER),
            0,
            "New user should have 0 claim time"
        );

        vm.prank(USER);
        faucet.distribution();

        uint256 remainingTime = faucet.getClaimTime(USER);
        assertGt(remainingTime, 0, "Should have remaining cooldown");
        assertLe(remainingTime, 24 hours, "Time should be <= cooldown");

        vm.warp(block.timestamp + 86401 seconds);
        assertEq(faucet.getClaimTime(USER), 0, "Should be 0 after cooldown");
    }

    function testFuzzDistributionAmount(uint256 amount) public {
        if (amount == 0) {
            amount = 1;
        } else if (amount > type(uint256).max / (10 ** 18)) {
            amount = type(uint256).max / (10 ** 18);
        }

        console.log("Bound result", amount);

        uint256 expectedAmount = amount * (10 ** 18);

        uint256 faucetBalance = expectedAmount;
        if (type(uint256).max - expectedAmount >= 1000 ether) {
            faucetBalance += 1000 ether;
        }
        deal(address(token), address(faucet), faucetBalance);

        vm.prank(OWNER);
        faucet.setDistributionAmount(amount);

        vm.prank(USER);
        faucet.distribution();

        assertEq(token.balanceOf(USER), expectedAmount, "Fuzz test failed");
    }

    function testEmergencyWithdrawAll() public {
        uint256 initialBalance = token.balanceOf(OWNER);
        uint256 faucetBalance = token.balanceOf(address(faucet));

        vm.prank(OWNER);
        faucet.emergencyWithdrawAll();

        assertEq(
            token.balanceOf(OWNER),
            initialBalance + faucetBalance,
            "Emergency withdrawal failed"
        );
    }

    function testZeroAmountValidation() public {
        vm.prank(OWNER);
        vm.expectRevert(Faucet.InvalidAmount.selector);
        faucet.setDistributionAmount(0);

        vm.prank(OWNER);
        vm.expectRevert(Faucet.InvalidAmount.selector);
        faucet.withdrawTokens(0);
    }
}
