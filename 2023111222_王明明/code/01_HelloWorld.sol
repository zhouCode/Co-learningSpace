// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 实用简洁HelloWorld合约
 * @dev 注重实用性和代码简洁性的智能合约
 * @author 王明明 (2023111222)
 * @notice 这个合约展示了简洁高效的编程风格
 */

contract PracticalHelloWorld {
    // 简洁的状态变量
    mapping(address => string) public messages;
    mapping(address => uint256) public timestamps;
    
    uint256 public totalMessages;
    address public owner;
    
    // 实用的事件定义
    event MessageUpdated(address indexed user, string message);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // 简洁的修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier validMessage(string memory _message) {
        require(bytes(_message).length > 0 && bytes(_message).length <= 100, "Invalid message");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        messages[msg.sender] = "Hello, Practical World!";
        timestamps[msg.sender] = block.timestamp;
        totalMessages = 1;
        
        emit MessageUpdated(msg.sender, messages[msg.sender]);
    }
    
    /**
     * @dev 设置消息 - 简洁实用的实现
     */
    function setMessage(string memory _message) public validMessage(_message) {
        bool isNewMessage = bytes(messages[msg.sender]).length == 0;
        
        messages[msg.sender] = _message;
        timestamps[msg.sender] = block.timestamp;
        
        if (isNewMessage) {
            totalMessages++;
        }
        
        emit MessageUpdated(msg.sender, _message);
    }
    
    /**
     * @dev 获取消息 - 直接简单
     */
    function getMessage(address _user) public view returns (string memory) {
        return messages[_user];
    }
    
    /**
     * @dev 获取自己的消息
     */
    function getMyMessage() public view returns (string memory) {
        return messages[msg.sender];
    }
    
    /**
     * @dev 批量获取消息 - 实用功能
     */
    function getMessages(address[] memory _users) 
        public 
        view 
        returns (string[] memory) 
    {
        string[] memory result = new string[](_users.length);
        for (uint256 i = 0; i < _users.length; i++) {
            result[i] = messages[_users[i]];
        }
        return result;
    }
    
    /**
     * @dev 检查用户是否有消息
     */
    function hasMessage(address _user) public view returns (bool) {
        return bytes(messages[_user]).length > 0;
    }
    
    /**
     * @dev 获取消息时间戳
     */
    function getMessageTime(address _user) public view returns (uint256) {
        return timestamps[_user];
    }
    
    /**
     * @dev 转移所有权 - 实用的管理功能
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        
        address previousOwner = owner;
        owner = _newOwner;
        
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
    
    /**
     * @dev 清除自己的消息
     */
    function clearMyMessage() public {
        require(bytes(messages[msg.sender]).length > 0, "No message to clear");
        
        delete messages[msg.sender];
        delete timestamps[msg.sender];
        totalMessages--;
        
        emit MessageUpdated(msg.sender, "");
    }
    
    /**
     * @dev 获取合约基本信息
     */
    function getContractInfo() public view returns (
        uint256 totalMessages_,
        address owner_,
        uint256 blockTime
    ) {
        return (totalMessages, owner, block.timestamp);
    }
}

/*
实用简洁设计特色：

1. 代码简洁性
   - 最少的状态变量
   - 直接的函数实现
   - 清晰的逻辑结构

2. 实用功能导向
   - 批量查询功能
   - 消息存在性检查
   - 时间戳记录

3. 高效实现
   - 避免复杂的数据结构
   - 直接的存储访问
   - 最小化gas消耗

4. 用户友好
   - 简单的接口设计
   - 清晰的错误信息
   - 直观的函数命名

5. 维护性
   - 代码结构清晰
   - 注释简洁明了
   - 易于理解和修改

这种设计体现了实用主义编程理念：
简洁高效、功能完整、易于维护。
*/