// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 安全导向HelloWorld合约
 * @dev 注重安全性和最佳实践的智能合约
 * @author 彭俊霖 (2023110917)
 * @notice 这个合约展示了安全编程的最佳实践
 */

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SecureHelloWorld is ReentrancyGuard, Pausable, Ownable {
    // 安全特性：消息存储与访问控制
    mapping(address => string) private userMessages;
    mapping(address => bool) public authorizedUsers;
    mapping(address => uint256) public messageCount;
    
    // 安全特性：速率限制
    mapping(address => uint256) public lastMessageTime;
    uint256 public constant MESSAGE_COOLDOWN = 60; // 60秒冷却时间
    
    // 安全特性：消息长度限制
    uint256 public constant MAX_MESSAGE_LENGTH = 200;
    uint256 public constant MIN_MESSAGE_LENGTH = 1;
    
    // 安全特性：合约状态监控
    uint256 public totalMessages;
    uint256 public totalUsers;
    bool public emergencyMode;
    
    // 安全特性：事件日志
    event MessageSet(address indexed user, string message, uint256 timestamp);
    event UserAuthorized(address indexed user, address indexed authorizer);
    event UserRevoked(address indexed user, address indexed revoker);
    event EmergencyModeToggled(bool enabled, address indexed admin);
    event SuspiciousActivity(address indexed user, string reason);
    
    // 安全修饰符
    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] || msg.sender == owner(), "Unauthorized access");
        _;
    }
    
    modifier rateLimited() {
        require(
            block.timestamp >= lastMessageTime[msg.sender] + MESSAGE_COOLDOWN,
            "Rate limit exceeded"
        );
        _;
    }
    
    modifier validMessage(string memory _message) {
        bytes memory messageBytes = bytes(_message);
        require(
            messageBytes.length >= MIN_MESSAGE_LENGTH && 
            messageBytes.length <= MAX_MESSAGE_LENGTH,
            "Invalid message length"
        );
        require(!_containsProhibitedContent(_message), "Prohibited content detected");
        _;
    }
    
    modifier notInEmergency() {
        require(!emergencyMode, "Contract in emergency mode");
        _;
    }
    
    constructor() {
        authorizedUsers[msg.sender] = true;
        totalUsers = 1;
        
        // 设置默认消息
        userMessages[msg.sender] = "Hello, Secure Blockchain World!";
        emit MessageSet(msg.sender, userMessages[msg.sender], block.timestamp);
    }
    
    /**
     * @dev 安全的消息设置函数
     * @param _message 要设置的消息内容
     */
    function setMessage(string memory _message) 
        public 
        nonReentrant 
        whenNotPaused 
        onlyAuthorized 
        rateLimited 
        validMessage(_message)
        notInEmergency
    {
        // 检查是否为新用户
        if (bytes(userMessages[msg.sender]).length == 0) {
            totalUsers++;
        }
        
        // 更新消息和统计
        userMessages[msg.sender] = _message;
        messageCount[msg.sender]++;
        totalMessages++;
        lastMessageTime[msg.sender] = block.timestamp;
        
        // 安全检查：检测异常行为
        _detectAnomalousActivity(msg.sender);
        
        emit MessageSet(msg.sender, _message, block.timestamp);
    }
    
    /**
     * @dev 安全的消息获取函数
     * @param _user 要查询的用户地址
     */
    function getMessage(address _user) 
        public 
        view 
        returns (string memory) 
    {
        require(_user != address(0), "Invalid address");
        
        // 隐私保护：只有授权用户或消息所有者可以查看
        require(
            msg.sender == _user || 
            authorizedUsers[msg.sender] || 
            msg.sender == owner(),
            "Access denied"
        );
        
        return userMessages[_user];
    }
    
    /**
     * @dev 获取自己的消息（无需权限检查）
     */
    function getMyMessage() public view returns (string memory) {
        return userMessages[msg.sender];
    }
    
    /**
     * @dev 授权用户访问权限
     * @param _user 要授权的用户地址
     */
    function authorizeUser(address _user) public onlyOwner {
        require(_user != address(0), "Invalid address");
        require(!authorizedUsers[_user], "Already authorized");
        
        authorizedUsers[_user] = true;
        emit UserAuthorized(_user, msg.sender);
    }
    
    /**
     * @dev 撤销用户访问权限
     * @param _user 要撤销权限的用户地址
     */
    function revokeUser(address _user) public onlyOwner {
        require(_user != address(0), "Invalid address");
        require(_user != owner(), "Cannot revoke owner");
        require(authorizedUsers[_user], "Not authorized");
        
        authorizedUsers[_user] = false;
        emit UserRevoked(_user, msg.sender);
    }
    
    /**
     * @dev 紧急暂停功能
     */
    function emergencyPause() public onlyOwner {
        _pause();
        emergencyMode = true;
        emit EmergencyModeToggled(true, msg.sender);
    }
    
    /**
     * @dev 恢复正常运行
     */
    function emergencyUnpause() public onlyOwner {
        _unpause();
        emergencyMode = false;
        emit EmergencyModeToggled(false, msg.sender);
    }
    
    /**
     * @dev 检测异常活动
     * @param _user 用户地址
     */
    function _detectAnomalousActivity(address _user) internal {
        // 检测频繁消息更新
        if (messageCount[_user] > 100) {
            emit SuspiciousActivity(_user, "Excessive message updates");
        }
        
        // 检测短时间内大量操作
        if (block.timestamp - lastMessageTime[_user] < 10) {
            emit SuspiciousActivity(_user, "Rapid successive operations");
        }
    }
    
    /**
     * @dev 检查禁止内容（简化实现）
     * @param _message 要检查的消息
     */
    function _containsProhibitedContent(string memory _message) internal pure returns (bool) {
        bytes memory messageBytes = bytes(_message);
        
        // 简单的内容过滤（实际项目中需要更复杂的过滤逻辑）
        // 检查是否包含特殊字符或潜在的恶意内容
        for (uint i = 0; i < messageBytes.length; i++) {
            bytes1 char = messageBytes[i];
            // 检查控制字符
            if (uint8(char) < 32 && uint8(char) != 10 && uint8(char) != 13) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev 获取用户统计信息
     * @param _user 用户地址
     */
    function getUserStats(address _user) 
        public 
        view 
        onlyAuthorized 
        returns (
            uint256 messageCount_,
            uint256 lastMessageTime_,
            bool isAuthorized,
            bool hasMessage
        ) 
    {
        return (
            messageCount[_user],
            lastMessageTime[_user],
            authorizedUsers[_user],
            bytes(userMessages[_user]).length > 0
        );
    }
    
    /**
     * @dev 获取合约统计信息
     */
    function getContractStats() 
        public 
        view 
        returns (
            uint256 totalMessages_,
            uint256 totalUsers_,
            bool isPaused,
            bool emergencyMode_
        ) 
    {
        return (
            totalMessages,
            totalUsers,
            paused(),
            emergencyMode
        );
    }
    
    /**
     * @dev 批量授权用户（管理员功能）
     * @param _users 用户地址数组
     */
    function batchAuthorizeUsers(address[] memory _users) public onlyOwner {
        require(_users.length <= 50, "Too many users"); // 防止gas耗尽
        
        for (uint256 i = 0; i < _users.length; i++) {
            if (_users[i] != address(0) && !authorizedUsers[_users[i]]) {
                authorizedUsers[_users[i]] = true;
                emit UserAuthorized(_users[i], msg.sender);
            }
        }
    }
    
    /**
     * @dev 安全的合约升级准备
     */
    function prepareUpgrade() public onlyOwner {
        emergencyPause();
        // 在实际升级中，这里会包含数据迁移逻辑
    }
    
    /**
     * @dev 检查合约健康状态
     */
    function healthCheck() public view returns (bool) {
        return !paused() && !emergencyMode && totalUsers > 0;
    }
}

/*
安全设计特色：

1. 多层安全防护
   - ReentrancyGuard防重入攻击
   - Pausable紧急暂停机制
   - Ownable权限管理

2. 访问控制系统
   - 细粒度权限管理
   - 用户授权机制
   - 隐私保护措施

3. 速率限制与防滥用
   - 消息发送冷却时间
   - 内容长度限制
   - 异常行为检测

4. 审计与监控
   - 完整的事件日志
   - 用户行为统计
   - 可疑活动报告

5. 紧急响应机制
   - 紧急暂停功能
   - 合约状态监控
   - 升级准备功能

这种设计体现了区块链安全的核心原则：
纵深防御、最小权限、可审计性。
*/