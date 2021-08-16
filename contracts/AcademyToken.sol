// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AcademyToken is ERC20, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor () ERC20("Academy Token", "ACDM") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, ADMIN_ROLE);
    }

    function mint(address to, uint256 amount) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "You should have a minter role"
        );
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(
            hasRole(BURNER_ROLE, msg.sender),
            "You should have a burner role"
        );
        _burn(from, amount);
    }
}
