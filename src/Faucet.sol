// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Faucet is Ownable {
    Token public immutable token;

    mapping(address => uint256) public distributionAddresses;
    mapping(address => uint256) public lastDistribute;

    event Distributed(address indexed to, uint256 indexed amount);

    uint256 public constant DISTRIBUTION = 100 * 10 ** 18; // 100 Tokens

    uint256 private setAmount;
    uint256 public time = 24 hours;

    error CooldownNotExpired();
    error AlreadyDistributed();
    error InsufficientFaucetBalance();
    error InvalidAmount();

    constructor(
        address tokenAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        token = Token(tokenAddress);
    }

    function distribution() external {
        address sender = msg.sender;

        uint256 currentTime = block.timestamp;

        uint256 amount = setAmount > 0 ? setAmount : DISTRIBUTION;

        if (currentTime < lastDistribute[sender] + time) {
            revert CooldownNotExpired();
        }

        if (token.balanceOf(address(this)) < amount) {
            revert InsufficientFaucetBalance();
        }

        lastDistribute[sender] = currentTime;
        distributionAddresses[sender] = amount;

        token.transferTo(sender, amount);

        emit Distributed(sender, amount);
    }

    function setDistributionAmount(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();

        if (amount > type(uint256).max / 10 ** 18) revert InvalidAmount();

        setAmount = amount * 10 ** 18;
    }

    function withdrawTokens(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();

        address contractOwner = owner();
        token.transferTo(contractOwner, amount);
    }

    function getClaimTime(address user) external view returns (uint256) {
        uint256 lastClaim = lastDistribute[user];
        uint256 currentTime = block.timestamp;

        if (currentTime < lastClaim + time) {
            return (lastClaim + time) - currentTime;
        }

        return 0;
    }

    function canClaim(address user) external view returns (bool) {
        return block.timestamp >= lastDistribute[user] + time;
    }

    function emergencyWithdrawAll() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transferTo(owner(), balance);
        }
    }
}
