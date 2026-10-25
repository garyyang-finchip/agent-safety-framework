// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @notice Evidence helper (not part of the ERC assets). Set as the operator of a guarded account, it
///         forwards `execute` calls from its owner and records the outcome as an event, so that a refused
///         action becomes an on-chain record with the revert data instead of a failed transaction.
interface IGuardedAccountLike {
    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory);
}

contract OperatorProbe {
    address public immutable owner;
    IGuardedAccountLike public immutable account;

    event Attempt(address indexed target, bytes4 selector, bool ok, bytes result);

    constructor(address owner_, IGuardedAccountLike account_) {
        owner = owner_;
        account = account_;
    }

    function attempt(address target, uint256 value, bytes calldata data) external returns (bool ok, bytes memory result) {
        require(msg.sender == owner, "probe: not owner");
        try account.execute(target, value, data) returns (bytes memory ret) {
            ok = true;
            result = ret;
        } catch (bytes memory err) {
            ok = false;
            result = err;
        }
        emit Attempt(target, data.length >= 4 ? bytes4(data[:4]) : bytes4(0), ok, result);
    }
}

/// @notice Evidence target (not part of the ERC assets): new exposure versus de-risking.
contract LendingDesk {
    mapping(address => uint256) public debt;
    mapping(address => uint256) public orders;

    event Borrowed(address indexed who, uint256 amount);
    event Repaid(address indexed who, uint256 amount);

    function borrow(uint256 amount) external { debt[msg.sender] += amount; emit Borrowed(msg.sender, amount); }
    function repay(uint256 amount) external { debt[msg.sender] -= amount; emit Repaid(msg.sender, amount); }
    function placeOrder() external { orders[msg.sender] += 1; }
    function cancelOrder() external { orders[msg.sender] -= 1; }
}
