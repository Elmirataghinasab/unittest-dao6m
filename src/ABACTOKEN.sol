// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ABACTOKEN is ERC20 {
    constructor() ERC20("Attribute Based Access Control Token", "ABACT") {}

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    function mint(address receiver, uint256 amount) public {
        _mint(receiver, amount);
    }
}
