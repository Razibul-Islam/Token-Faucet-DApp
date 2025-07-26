// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Token} from "../src/Token.sol";

contract Faucet is Token {
    Token public token;

    mapping(address => uint256) public DistributionAddresses;

    event distributed(address indexed to, uint256 amount);

    uint256 public constant DISTRIBUTION = 100 * 10 ** 18; // 100 Tokens

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
    }

    function distribution() public {
        require(
            token.balanceOf(address(this)) >= DISTRIBUTION,
            "Not Enough Tokens in Faucet"
        );
        require(DistributionAddresses[msg.sender] == 0, "ALready Distributed");

        token.transferTo(msg.sender, DISTRIBUTION);
        DistributionAddresses[msg.sender] = DISTRIBUTION;
        emit distributed(msg.sender, DISTRIBUTION);
    }
}
