// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VEILToken is ERC20, Ownable {
    constructor() ERC20("VEIL Token", "VEIL") Ownable(msg.sender) {
        _mint(msg.sender, 100_000_000 * 1 ether);
    }
}
