// SPDX-Lisence-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Faucet} from "../src/Faucet.sol";
import {Token} from "../src/Token.sol";

contract TestFaucet is Test {
    Faucet public faucet;
    Token public token;

    event distributed(address indexed to, uint256 amount);

    address public USER = makeAddr("user");
    uint256 public constant DISTRIBUTION_TOKEN = 100 * 10 ** 18;

    function setUp() public {
        // Deploy the contracts
        token = new Token();
        faucet = new Faucet(address(token));

        // Fund the contract
        token.transferTo(address(faucet), 1000 ether);
    }

    function testDistribution() public {
        // Demo User Claim Token
        vm.prank(USER);
        faucet.distribution();

        // Verify Token Received
        assertEq(
            token.balanceOf(USER),
            DISTRIBUTION_TOKEN,
            "Token are not transfared"
        );

        // verify User can't claim twice
        vm.prank(USER);
        vm.expectRevert("ALready Distributed");
        faucet.distribution();
    }

    function testInsufficientFaucetBalance() public {
        deal(address(token), address(faucet), 0);
        token.transferTo(address(this), token.balanceOf(address(faucet)));

        // Attemp to claim revert
        vm.prank(USER);
        vm.expectRevert("Not Enough Tokens in Faucet");
        faucet.distribution();
    }

    function testDistributionEvent() public {
        // Check if event is emit
        vm.expectEmit(true, true, false, true);
        emit distributed(USER, DISTRIBUTION_TOKEN);

        vm.prank(USER);
        faucet.distribution();
    }
}
