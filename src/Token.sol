// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Free Fungible Token", "FFT") {
        _mint(msg.sender, 1e6 * 10 ** decimals());
    }

    function balanceOfSender() public view returns (uint256) {
        return super.balanceOf(msg.sender);
    }

    function mintTo(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transferTo(address to, uint256 amount) public {
        require(balanceOfSender() >= amount, "Insufficient balance");
        transfer(to, amount);
    }
}
