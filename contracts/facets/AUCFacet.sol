// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

contract AUCFacet {
    LibAppStorage.AppStorage internal s;

    function name() public pure returns (string memory) {
        return "AUC Token";
    }

    function symbol() public pure returns (string memory) {
        return "AUC";
    }

    function decimal() public pure returns (uint256) {
        return 18;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() public view returns (uint256) {
        return s.totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return s.balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return s.allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    function transferFrom(
        address spender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        uint256 _allowance = s.allowances[spender][msg.sender];
        require(_allowance >= amount, "Not enough allowance");
        s.allowances[spender][msg.sender] =
            s.allowances[spender][msg.sender] -
            amount;
        return _transfer(spender, recipient, amount);
    }

    function mint(address account, uint256 amount) public {
        LibDiamond.enforceIsContractOwner();
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        LibDiamond.enforceIsContractOwner();
        _burn(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            s.balances[sender] >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        s.balances[sender] -= amount;
        s.balances[recipient] += amount;
        s.lastInteraction = msg.sender;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        s.totalSupply += amount;
        s.balances[account] += amount;
        s.lastInteraction = msg.sender;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(
            s.balances[account] >= amount,
            "ERC20: burn amount exceeds balance"
        );
        s.balances[account] -= amount;
        s.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal returns (bool) {
        require(spender != address(0), "ERC20: approve to the zero address");
        s.allowances[owner][spender] = amount;
        s.lastInteraction = msg.sender;
        emit Approval(owner, spender, amount);
        return true;
    }
}
