// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BasicToken - 简洁版代币合约
 * @author 王鹏 (2023110726)
 * @notice 实现基础ERC20功能的简洁代币合约
 */
contract BasicToken {
    string public name = "SimpleToken";
    string public symbol = "SIM";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        require(to != address(0), "Invalid address");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        require(to != address(0), "Invalid address");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
}

/*
=== 王鹏的学习笔记 ===

简洁代币合约设计原则：
1. 核心功能优先 - 只实现必要的ERC20功能
2. 直观的状态管理 - 使用标准的mapping结构
3. 清晰的错误处理 - require语句简洁明了
4. 标准化命名 - 遵循ERC20标准命名

简洁版特点：
- 去除复杂的权限管理
- 使用基础的算术运算（Solidity 0.8+自带溢出检查）
- 标准的事件发射
- 最小化的构造函数参数

与复杂版本的区别：
- 没有铸造/销毁功能
- 没有暂停机制
- 没有多重签名
- 没有复杂的费用机制

这种简洁设计的优势：
- 代码易于审计
- gas消耗较低
- 部署成本低
- 维护简单

适用场景：
- 简单的代币发行
- 学习和测试
- 小型项目
*/