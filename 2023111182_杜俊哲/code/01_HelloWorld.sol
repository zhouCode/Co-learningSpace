// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 模块化架构HelloWorld合约
 * @dev 采用模块化设计和可扩展架构的智能合约
 * @author 杜俊哲 (2023111182)
 * @notice 这个合约展示了模块化设计和可扩展架构的最佳实践
 */

// 接口定义模块
interface IMessageStorage {
    function storeMessage(address user, string memory message) external;
    function getMessage(address user) external view returns (string memory);
    function deleteMessage(address user) external;
}

interface IUserManager {
    function registerUser(address user) external;
    function isRegistered(address user) external view returns (bool);
    function getUserInfo(address user) external view returns (uint256, uint256, bool);
}

interface IEventLogger {
    function logMessageEvent(address user, string memory message, uint256 timestamp) external;
    function logUserEvent(address user, string memory eventType) external;
}

// 抽象合约模块
abstract contract BaseModule {
    address public moduleManager;
    bool public isActive;
    string public moduleName;
    string public moduleVersion;
    
    modifier onlyManager() {
        require(msg.sender == moduleManager, "Only module manager");
        _;
    }
    
    modifier whenActive() {
        require(isActive, "Module is inactive");
        _;
    }
    
    constructor(string memory _name, string memory _version) {
        moduleManager = msg.sender;
        isActive = true;
        moduleName = _name;
        moduleVersion = _version;
    }
    
    function setActive(bool _active) external onlyManager {
        isActive = _active;
    }
    
    function upgradeModule(string memory _newVersion) external onlyManager {
        moduleVersion = _newVersion;
    }
}

// 消息存储模块
contract MessageStorageModule is BaseModule, IMessageStorage {
    mapping(address => string) private messages;
    mapping(address => uint256) private messageTimestamps;
    mapping(address => uint256) private messageVersions;
    
    event MessageStored(address indexed user, string message, uint256 version);
    event MessageDeleted(address indexed user);
    
    constructor() BaseModule("MessageStorage", "1.0.0") {}
    
    function storeMessage(address user, string memory message) 
        external 
        override 
        onlyManager 
        whenActive 
    {
        require(bytes(message).length > 0, "Empty message");
        require(bytes(message).length <= 500, "Message too long");
        
        messages[user] = message;
        messageTimestamps[user] = block.timestamp;
        messageVersions[user]++;
        
        emit MessageStored(user, message, messageVersions[user]);
    }
    
    function getMessage(address user) 
        external 
        view 
        override 
        returns (string memory) 
    {
        return messages[user];
    }
    
    function deleteMessage(address user) 
        external 
        override 
        onlyManager 
        whenActive 
    {
        delete messages[user];
        delete messageTimestamps[user];
        emit MessageDeleted(user);
    }
    
    function getMessageInfo(address user) 
        external 
        view 
        returns (string memory message, uint256 timestamp, uint256 version) 
    {
        return (messages[user], messageTimestamps[user], messageVersions[user]);
    }
}

// 用户管理模块
contract UserManagerModule is BaseModule, IUserManager {
    struct User {
        bool isRegistered;
        uint256 registrationTime;
        uint256 lastActivityTime;
        uint256 activityCount;
        string userType;
    }
    
    mapping(address => User) private users;
    address[] private userList;
    uint256 public totalUsers;
    
    event UserRegistered(address indexed user, uint256 timestamp);
    event UserActivityUpdated(address indexed user, uint256 activityCount);
    
    constructor() BaseModule("UserManager", "1.0.0") {}
    
    function registerUser(address user) 
        external 
        override 
        onlyManager 
        whenActive 
    {
        require(!users[user].isRegistered, "User already registered");
        
        users[user] = User({
            isRegistered: true,
            registrationTime: block.timestamp,
            lastActivityTime: block.timestamp,
            activityCount: 0,
            userType: "standard"
        });
        
        userList.push(user);
        totalUsers++;
        
        emit UserRegistered(user, block.timestamp);
    }
    
    function isRegistered(address user) 
        external 
        view 
        override 
        returns (bool) 
    {
        return users[user].isRegistered;
    }
    
    function getUserInfo(address user) 
        external 
        view 
        override 
        returns (uint256 registrationTime, uint256 activityCount, bool isRegistered) 
    {
        User memory userInfo = users[user];
        return (userInfo.registrationTime, userInfo.activityCount, userInfo.isRegistered);
    }
    
    function updateUserActivity(address user) external onlyManager whenActive {
        require(users[user].isRegistered, "User not registered");
        
        users[user].lastActivityTime = block.timestamp;
        users[user].activityCount++;
        
        emit UserActivityUpdated(user, users[user].activityCount);
    }
    
    function setUserType(address user, string memory userType) external onlyManager {
        require(users[user].isRegistered, "User not registered");
        users[user].userType = userType;
    }
    
    function getUserList() external view returns (address[] memory) {
        return userList;
    }
}

// 事件日志模块
contract EventLoggerModule is BaseModule, IEventLogger {
    struct LogEntry {
        address user;
        string eventType;
        string data;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    LogEntry[] private eventLogs;
    mapping(address => uint256[]) private userEventIndices;
    
    event EventLogged(
        address indexed user, 
        string indexed eventType, 
        string data, 
        uint256 timestamp
    );
    
    constructor() BaseModule("EventLogger", "1.0.0") {}
    
    function logMessageEvent(address user, string memory message, uint256 timestamp) 
        external 
        override 
        onlyManager 
        whenActive 
    {
        _logEvent(user, "MESSAGE_SET", message, timestamp);
    }
    
    function logUserEvent(address user, string memory eventType) 
        external 
        override 
        onlyManager 
        whenActive 
    {
        _logEvent(user, eventType, "", block.timestamp);
    }
    
    function _logEvent(
        address user, 
        string memory eventType, 
        string memory data, 
        uint256 timestamp
    ) internal {
        LogEntry memory newLog = LogEntry({
            user: user,
            eventType: eventType,
            data: data,
            timestamp: timestamp,
            blockNumber: block.number
        });
        
        eventLogs.push(newLog);
        userEventIndices[user].push(eventLogs.length - 1);
        
        emit EventLogged(user, eventType, data, timestamp);
    }
    
    function getUserEvents(address user) 
        external 
        view 
        returns (LogEntry[] memory) 
    {
        uint256[] memory indices = userEventIndices[user];
        LogEntry[] memory userEvents = new LogEntry[](indices.length);
        
        for (uint256 i = 0; i < indices.length; i++) {
            userEvents[i] = eventLogs[indices[i]];
        }
        
        return userEvents;
    }
    
    function getRecentEvents(uint256 count) 
        external 
        view 
        returns (LogEntry[] memory) 
    {
        require(count > 0, "Count must be positive");
        
        uint256 totalEvents = eventLogs.length;
        uint256 actualCount = count > totalEvents ? totalEvents : count;
        LogEntry[] memory recentEvents = new LogEntry[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            recentEvents[i] = eventLogs[totalEvents - actualCount + i];
        }
        
        return recentEvents;
    }
}

// 主合约 - 模块管理器
contract ModularHelloWorld {
    // 模块注册表
    mapping(string => address) public modules;
    mapping(address => bool) public authorizedModules;
    string[] public moduleNames;
    
    // 核心组件
    IMessageStorage public messageStorage;
    IUserManager public userManager;
    IEventLogger public eventLogger;
    
    // 管理员权限
    address public admin;
    mapping(address => bool) public operators;
    
    // 合约状态
    bool public isInitialized;
    string public constant VERSION = "2.0.0";
    
    event ModuleRegistered(string indexed moduleName, address indexed moduleAddress);
    event ModuleUpgraded(string indexed moduleName, address indexed oldAddress, address indexed newAddress);
    event MessageSet(address indexed user, string message);
    event UserRegistered(address indexed user);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == admin, "Only operator");
        _;
    }
    
    modifier whenInitialized() {
        require(isInitialized, "Contract not initialized");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        operators[msg.sender] = true;
    }
    
    /**
     * @dev 初始化合约模块
     */
    function initialize() external onlyAdmin {
        require(!isInitialized, "Already initialized");
        
        // 部署核心模块
        MessageStorageModule msgStorage = new MessageStorageModule();
        UserManagerModule usrManager = new UserManagerModule();
        EventLoggerModule evtLogger = new EventLoggerModule();
        
        // 注册模块
        _registerModule("MessageStorage", address(msgStorage));
        _registerModule("UserManager", address(usrManager));
        _registerModule("EventLogger", address(evtLogger));
        
        // 设置接口引用
        messageStorage = IMessageStorage(address(msgStorage));
        userManager = IUserManager(address(usrManager));
        eventLogger = IEventLogger(address(evtLogger));
        
        isInitialized = true;
    }
    
    /**
     * @dev 设置消息 - 主要业务逻辑
     */
    function setMessage(string memory _message) external whenInitialized {
        require(bytes(_message).length > 0, "Empty message");
        
        address user = msg.sender;
        
        // 检查用户是否已注册，如果没有则自动注册
        if (!userManager.isRegistered(user)) {
            userManager.registerUser(user);
            eventLogger.logUserEvent(user, "USER_REGISTERED");
            emit UserRegistered(user);
        }
        
        // 存储消息
        messageStorage.storeMessage(user, _message);
        
        // 更新用户活动
        UserManagerModule(modules["UserManager"]).updateUserActivity(user);
        
        // 记录事件
        eventLogger.logMessageEvent(user, _message, block.timestamp);
        
        emit MessageSet(user, _message);
    }
    
    /**
     * @dev 获取消息
     */
    function getMessage(address _user) external view whenInitialized returns (string memory) {
        return messageStorage.getMessage(_user);
    }
    
    /**
     * @dev 获取自己的消息
     */
    function getMyMessage() external view whenInitialized returns (string memory) {
        return messageStorage.getMessage(msg.sender);
    }
    
    /**
     * @dev 注册新模块
     */
    function registerModule(string memory _name, address _moduleAddress) 
        external 
        onlyAdmin 
    {
        _registerModule(_name, _moduleAddress);
    }
    
    function _registerModule(string memory _name, address _moduleAddress) internal {
        require(_moduleAddress != address(0), "Invalid module address");
        require(modules[_name] == address(0), "Module already exists");
        
        modules[_name] = _moduleAddress;
        authorizedModules[_moduleAddress] = true;
        moduleNames.push(_name);
        
        emit ModuleRegistered(_name, _moduleAddress);
    }
    
    /**
     * @dev 升级模块
     */
    function upgradeModule(string memory _name, address _newModuleAddress) 
        external 
        onlyAdmin 
    {
        require(_newModuleAddress != address(0), "Invalid module address");
        address oldAddress = modules[_name];
        require(oldAddress != address(0), "Module does not exist");
        
        // 更新模块地址
        modules[_name] = _newModuleAddress;
        authorizedModules[oldAddress] = false;
        authorizedModules[_newModuleAddress] = true;
        
        // 更新接口引用
        if (keccak256(bytes(_name)) == keccak256(bytes("MessageStorage"))) {
            messageStorage = IMessageStorage(_newModuleAddress);
        } else if (keccak256(bytes(_name)) == keccak256(bytes("UserManager"))) {
            userManager = IUserManager(_newModuleAddress);
        } else if (keccak256(bytes(_name)) == keccak256(bytes("EventLogger"))) {
            eventLogger = IEventLogger(_newModuleAddress);
        }
        
        emit ModuleUpgraded(_name, oldAddress, _newModuleAddress);
    }
    
    /**
     * @dev 获取合约信息
     */
    function getContractInfo() external view returns (
        string memory version,
        bool initialized,
        uint256 moduleCount,
        address admin_
    ) {
        return (VERSION, isInitialized, moduleNames.length, admin);
    }
    
    /**
     * @dev 获取所有模块信息
     */
    function getAllModules() external view returns (
        string[] memory names,
        address[] memory addresses
    ) {
        names = moduleNames;
        addresses = new address[](moduleNames.length);
        
        for (uint256 i = 0; i < moduleNames.length; i++) {
            addresses[i] = modules[moduleNames[i]];
        }
    }
    
    /**
     * @dev 添加操作员
     */
    function addOperator(address _operator) external onlyAdmin {
        operators[_operator] = true;
    }
    
    /**
     * @dev 移除操作员
     */
    function removeOperator(address _operator) external onlyAdmin {
        require(_operator != admin, "Cannot remove admin");
        operators[_operator] = false;
    }
    
    /**
     * @dev 紧急暂停模块
     */
    function emergencyPauseModule(string memory _name) external onlyAdmin {
        address moduleAddress = modules[_name];
        require(moduleAddress != address(0), "Module does not exist");
        
        BaseModule(moduleAddress).setActive(false);
    }
    
    /**
     * @dev 恢复模块
     */
    function resumeModule(string memory _name) external onlyAdmin {
        address moduleAddress = modules[_name];
        require(moduleAddress != address(0), "Module does not exist");
        
        BaseModule(moduleAddress).setActive(true);
    }
}

/*
模块化架构特色：

1. 接口分离
   - 清晰的接口定义
   - 模块间松耦合
   - 易于测试和维护

2. 可扩展设计
   - 动态模块注册
   - 热插拔升级
   - 版本管理

3. 职责分离
   - 消息存储模块
   - 用户管理模块
   - 事件日志模块

4. 统一管理
   - 中央模块管理器
   - 权限控制系统
   - 生命周期管理

5. 企业级特性
   - 模块升级机制
   - 紧急暂停功能
   - 操作员权限体系

这种设计体现了软件工程的核心原则：
单一职责、开闭原则、依赖倒置。
*/