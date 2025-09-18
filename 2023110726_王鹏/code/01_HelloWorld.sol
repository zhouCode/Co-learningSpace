// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title HelloWorld - 简洁版智能合约
 * @author 王鹏 (2023110726)
 * @notice 这是一个追求简洁明了的HelloWorld合约
 */
contract HelloWorld {
    string public message = "Hello, World!";
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function setMessage(string memory _message) public {
        require(msg.sender == owner, "Only owner");
        message = _message;
    }
    
    function getMessage() public view returns (string memory) {
        return message;
    }
}

/*
=== 王鹏的学习笔记 ===

简洁明了编程风格的核心原则：
1. 代码即文档 - 变量和函数命名要清晰
2. 最小化复杂度 - 避免过度设计
3. 单一职责 - 每个函数只做一件事
4. 减少依赖 - 尽量使用原生功能

这个HelloWorld合约体现了简洁风格：
- 只有必要的功能：存储和修改消息
- 清晰的访问控制：只有owner可以修改
- 简单的错误处理：使用require
- 直观的函数命名：getMessage, setMessage

简洁不等于简陋，而是在保证功能的前提下，
用最少的代码实现最清晰的逻辑。

学习要点：
- 避免过度抽象
- 优先可读性而非炫技
- 每行代码都有明确目的
- 注释简洁但足够说明问题
*/