// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // 使用最新稳定版本以获得最新安全特性

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SecureHelloWorld - 安全加固版智能合约
 * @author 涂雨欣 (2023110835)
 * @notice 这是一个注重安全性的HelloWorld合约，集成多重安全机制
 * @dev 实现了重入攻击防护、访问控制、紧急暂停等安全特性
 */
contract SecureHelloWorld is ReentrancyGuard, Ownable, Pausable {
    // 使用自定义错误节省gas并提供更好的错误信息
    error InvalidMessageLength();
    error EmptyMessage();
    error UnauthorizedAccess(address caller);
    error ContractPaused();
    
    // 状态变量
    string private _message;
    uint256 public constant MAX_MESSAGE_LENGTH = 200;
    uint256 public messageUpdateCount;
    
    // 事件定义
    event MessageUpdated(address indexed updater, string newMessage, uint256 timestamp);
    event SecurityEvent(string eventType, address indexed user, uint256 timestamp);
    
    // 修饰符：额外的安全检查
    modifier validMessage(string memory _msg) {
        if (bytes(_msg).length == 0) revert EmptyMessage();
        if (bytes(_msg).length > MAX_MESSAGE_LENGTH) revert InvalidMessageLength();
        _;
    }
    
    modifier whenNotPausedCustom() {
        if (paused()) revert ContractPaused();
        _;
    }
    
    /**
     * @dev 构造函数，初始化合约状态
     * @param initialMessage 初始消息内容
     */
    constructor(string memory initialMessage) 
        validMessage(initialMessage) 
    {
        _message = initialMessage;
        emit MessageUpdated(msg.sender, initialMessage, block.timestamp);
    }
    
    /**
     * @dev 安全地设置消息内容
     * @param newMessage 新的消息内容
     */
    function setMessage(string memory newMessage) 
        external 
        onlyOwner 
        nonReentrant 
        whenNotPausedCustom 
        validMessage(newMessage) 
    {
        string memory oldMessage = _message;
        _message = newMessage;
        messageUpdateCount++;
        
        emit MessageUpdated(msg.sender, newMessage, block.timestamp);
        emit SecurityEvent("MESSAGE_UPDATED", msg.sender, block.timestamp);
        
        // 安全日志：记录敏感操作
        if (keccak256(bytes(oldMessage)) != keccak256(bytes(newMessage))) {
            emit SecurityEvent("MESSAGE_CHANGED", msg.sender, block.timestamp);
        }
    }
    
    /**
     * @dev 获取消息内容（只读函数）
     * @return 当前消息内容
     */
    function getMessage() external view returns (string memory) {
        return _message;
    }
    
    /**
     * @dev 紧急暂停合约（仅owner）
     */
    function pause() external onlyOwner {
        _pause();
        emit SecurityEvent("CONTRACT_PAUSED", msg.sender, block.timestamp);
    }
    
    /**
     * @dev 恢复合约运行（仅owner）
     */
    function unpause() external onlyOwner {
        _unpause();
        emit SecurityEvent("CONTRACT_UNPAUSED", msg.sender, block.timestamp);
    }
    
    /**
     * @dev 安全的合约销毁函数
     */
    function destroy() external onlyOwner {
        emit SecurityEvent("CONTRACT_DESTROYED", msg.sender, block.timestamp);
        selfdestruct(payable(owner()));
    }
    
    /**
     * @dev 防止意外接收以太币
     */
    receive() external payable {
        revert("Contract does not accept Ether");
    }
    
    fallback() external {
        revert("Function does not exist");
    }
}

/*
=== 涂雨欣的安全学习笔记 ===

智能合约安全设计的核心原则：

1. 【防御性编程】
   - 使用最新的Solidity版本获得安全特性
   - 输入验证：检查所有外部输入
   - 边界检查：防止数组越界和整数溢出
   - 状态检查：确保合约状态的一致性

2. 【访问控制】
   - 继承OpenZeppelin的Ownable实现所有权管理
   - 使用修饰符限制函数访问权限
   - 记录所有敏感操作的日志

3. 【重入攻击防护】
   - 使用ReentrancyGuard防止重入攻击
   - 遵循"检查-效果-交互"模式
   - 状态更新在外部调用之前完成

4. 【紧急响应机制】
   - 实现Pausable暂停功能
   - 提供紧急停止和恢复机制
   - 合约销毁功能（慎用）

5. 【错误处理】
   - 使用自定义错误节省gas
   - 提供清晰的错误信息
   - 避免静默失败

6. 【事件日志】
   - 记录所有重要状态变更
   - 安全事件的详细日志
   - 便于监控和审计

7. 【代码质量】
   - 详细的注释和文档
   - 遵循最佳实践
   - 代码审计友好

安全开发的思维模式：
"假设一切都可能出错，为最坏的情况做准备"

常见安全威胁及防护：
- 重入攻击 → ReentrancyGuard
- 权限滥用 → 严格的访问控制
- 整数溢出 → Solidity 0.8+自动检查
- 拒绝服务 → 输入验证和gas限制
- 前端运行 → 使用commit-reveal模式
*/