// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelloWorld - 实用主义的智能合约入门
 * @author 唐秋平 (2023110659)
 * @notice 注重实际应用场景的基础合约实现
 * @dev 以解决实际问题为导向的合约设计
 * 学习日期: 2024年10月16日
 */

/**
 * @title HelloWorld合约 - 实用主义设计
 * @dev 这个合约展示了实用主义编程的核心理念：
 * 1. 解决实际问题
 * 2. 简单有效的实现
 * 3. 用户友好的接口
 * 4. 实际场景的考虑
 */
contract HelloWorld {
    // ============ 状态变量 ============
    
    /// @dev 合约所有者
    address public owner;
    
    /// @dev 问候语存储
    string private greeting;
    
    /// @dev 访问计数器 - 实用功能：统计使用情况
    uint256 public accessCount;
    
    /// @dev 用户问候记录 - 实用功能：个性化体验
    mapping(address => string) public userGreetings;
    
    /// @dev 用户访问次数 - 实用功能：用户行为分析
    mapping(address => uint256) public userAccessCount;
    
    /// @dev 多语言支持 - 实用功能：国际化
    mapping(string => string) public translations;
    
    /// @dev 合约暂停状态 - 实用功能：紧急控制
    bool public isPaused;
    
    // ============ 事件定义 ============
    
    /// @notice 问候语更新事件
    event GreetingUpdated(address indexed user, string oldGreeting, string newGreeting);
    
    /// @notice 用户问候事件
    event UserGreeted(address indexed user, string greeting, uint256 timestamp);
    
    /// @notice 翻译添加事件
    event TranslationAdded(string language, string translation);
    
    /// @notice 合约状态变更事件
    event ContractStatusChanged(bool isPaused, address changedBy);
    
    // ============ 修饰符 ============
    
    /// @dev 仅所有者修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /// @dev 合约未暂停修饰符
    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }
    
    /// @dev 有效地址修饰符
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数 - 实用主义：提供合理的默认值
     * @param _initialGreeting 初始问候语
     */
    constructor(string memory _initialGreeting) {
        owner = msg.sender;
        
        // 实用考虑：提供默认问候语
        if (bytes(_initialGreeting).length == 0) {
            greeting = "Hello, World!";
        } else {
            greeting = _initialGreeting;
        }
        
        // 实用功能：预设常用语言翻译
        _initializeTranslations();
        
        isPaused = false;
        accessCount = 0;
        
        emit GreetingUpdated(msg.sender, "", greeting);
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 获取问候语 - 实用主义：简单直接的接口
     * @return 当前问候语
     */
    function getGreeting() public whenNotPaused returns (string memory) {
        // 实用功能：记录访问统计
        accessCount++;
        userAccessCount[msg.sender]++;
        
        // 实用功能：个性化问候
        string memory userGreeting = userGreetings[msg.sender];
        if (bytes(userGreeting).length > 0) {
            emit UserGreeted(msg.sender, userGreeting, block.timestamp);
            return userGreeting;
        }
        
        emit UserGreeted(msg.sender, greeting, block.timestamp);
        return greeting;
    }
    
    /**
     * @dev 设置问候语 - 实用主义：允许用户自定义
     * @param _newGreeting 新的问候语
     */
    function setGreeting(string memory _newGreeting) public whenNotPaused {
        require(bytes(_newGreeting).length > 0, "Greeting cannot be empty");
        require(bytes(_newGreeting).length <= 100, "Greeting too long"); // 实用限制
        
        string memory oldGreeting = greeting;
        greeting = _newGreeting;
        
        emit GreetingUpdated(msg.sender, oldGreeting, _newGreeting);
    }
    
    /**
     * @dev 设置个人问候语 - 实用功能：个性化体验
     * @param _personalGreeting 个人问候语
     */
    function setPersonalGreeting(string memory _personalGreeting) public whenNotPaused {
        require(bytes(_personalGreeting).length <= 100, "Personal greeting too long");
        
        string memory oldPersonalGreeting = userGreetings[msg.sender];
        userGreetings[msg.sender] = _personalGreeting;
        
        emit GreetingUpdated(msg.sender, oldPersonalGreeting, _personalGreeting);
    }
    
    /**
     * @dev 获取多语言问候语 - 实用功能：国际化支持
     * @param _language 语言代码 (如: "zh", "en", "ja")
     * @return 对应语言的问候语
     */
    function getGreetingInLanguage(string memory _language) public view returns (string memory) {
        string memory translation = translations[_language];
        if (bytes(translation).length > 0) {
            return translation;
        }
        return greeting; // 默认返回原问候语
    }
    
    /**
     * @dev 批量问候 - 实用功能：提高效率
     * @param _addresses 地址数组
     * @return 问候语数组
     */
    function batchGreet(address[] memory _addresses) public view returns (string[] memory) {
        require(_addresses.length <= 10, "Too many addresses"); // 实用限制：防止gas耗尽
        
        string[] memory greetings = new string[](_addresses.length);
        
        for (uint256 i = 0; i < _addresses.length; i++) {
            string memory userGreeting = userGreetings[_addresses[i]];
            if (bytes(userGreeting).length > 0) {
                greetings[i] = userGreeting;
            } else {
                greetings[i] = greeting;
            }
        }
        
        return greetings;
    }
    
    // ============ 实用工具函数 ============
    
    /**
     * @dev 获取合约统计信息 - 实用功能：数据分析
     * @return totalAccess 总访问次数
     * @return uniqueUsers 唯一用户数（近似）
     * @return currentGreeting 当前问候语
     */
    function getContractStats() public view returns (
        uint256 totalAccess,
        uint256 uniqueUsers,
        string memory currentGreeting
    ) {
        // 注意：uniqueUsers是近似值，实际实现需要更复杂的逻辑
        return (accessCount, accessCount > 0 ? 1 : 0, greeting);
    }
    
    /**
     * @dev 获取用户统计 - 实用功能：个人数据
     * @param _user 用户地址
     * @return userAccess 用户访问次数
     * @return hasPersonalGreeting 是否有个人问候语
     * @return personalGreeting 个人问候语
     */
    function getUserStats(address _user) public view returns (
        uint256 userAccess,
        bool hasPersonalGreeting,
        string memory personalGreeting
    ) {
        string memory userGreeting = userGreetings[_user];
        return (
            userAccessCount[_user],
            bytes(userGreeting).length > 0,
            userGreeting
        );
    }
    
    /**
     * @dev 检查问候语有效性 - 实用工具：输入验证
     * @param _greeting 待检查的问候语
     * @return isValid 是否有效
     * @return reason 无效原因
     */
    function validateGreeting(string memory _greeting) public pure returns (
        bool isValid,
        string memory reason
    ) {
        if (bytes(_greeting).length == 0) {
            return (false, "Greeting cannot be empty");
        }
        if (bytes(_greeting).length > 100) {
            return (false, "Greeting too long (max 100 characters)");
        }
        return (true, "Valid greeting");
    }
    
    // ============ 管理功能 ============
    
    /**
     * @dev 添加翻译 - 实用功能：扩展多语言支持
     * @param _language 语言代码
     * @param _translation 翻译内容
     */
    function addTranslation(string memory _language, string memory _translation) public onlyOwner {
        require(bytes(_language).length > 0, "Language code cannot be empty");
        require(bytes(_translation).length > 0, "Translation cannot be empty");
        require(bytes(_translation).length <= 100, "Translation too long");
        
        translations[_language] = _translation;
        emit TranslationAdded(_language, _translation);
    }
    
    /**
     * @dev 暂停/恢复合约 - 实用功能：紧急控制
     * @param _pause 是否暂停
     */
    function setPaused(bool _pause) public onlyOwner {
        isPaused = _pause;
        emit ContractStatusChanged(_pause, msg.sender);
    }
    
    /**
     * @dev 转移所有权 - 实用功能：管理权转移
     * @param _newOwner 新所有者地址
     */
    function transferOwnership(address _newOwner) public onlyOwner validAddress(_newOwner) {
        require(_newOwner != owner, "New owner must be different");
        owner = _newOwner;
    }
    
    /**
     * @dev 重置统计数据 - 实用功能：数据管理
     */
    function resetStats() public onlyOwner {
        accessCount = 0;
        // 注意：用户个人统计不会被重置，保护用户数据
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 初始化翻译 - 实用功能：预设常用翻译
     */
    function _initializeTranslations() private {
        translations["en"] = "Hello, World!";
        translations["zh"] = "你好，世界！";
        translations["ja"] = "こんにちは、世界！";
        translations["ko"] = "안녕하세요, 세계!";
        translations["es"] = "¡Hola, Mundo!";
        translations["fr"] = "Bonjour, le monde!";
        translations["de"] = "Hallo, Welt!";
        translations["ru"] = "Привет, мир!";
    }
    
    // ============ 应急功能 ============
    
    /**
     * @dev 应急提取 - 实用功能：资金安全
     * 虽然这个合约不处理资金，但展示了实用的安全考虑
     */
    function emergencyWithdraw() public onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev 接收以太币 - 实用功能：支持捐赠
     */
    receive() external payable {
        // 实用考虑：记录捐赠但不做复杂处理
    }
    
    /**
     * @dev 回退函数 - 实用功能：兼容性
     */
    fallback() external payable {
        // 实用考虑：提供基本的回退处理
    }
}

/**
 * 个人学习笔记 - 唐秋平
 * 
 * 实用主义编程的核心理念：
 * 1. 解决实际问题：每个功能都有明确的使用场景
 * 2. 用户体验优先：提供友好的接口和有用的功能
 * 3. 实际约束考虑：gas限制、字符串长度限制等
 * 4. 错误处理完善：提供清晰的错误信息
 * 
 * 实用功能的设计思路：
 * - 访问统计：了解合约使用情况
 * - 个性化问候：提升用户体验
 * - 多语言支持：扩大用户群体
 * - 批量操作：提高操作效率
 * - 数据验证：确保输入有效性
 * - 紧急控制：应对突发情况
 * 
 * 实际应用场景考虑：
 * - 国际化需求：多语言翻译功能
 * - 用户行为分析：访问统计和用户数据
 * - 系统维护：暂停功能和数据重置
 * - 资金安全：应急提取功能
 * - 兼容性：fallback和receive函数
 * 
 * 实用主义vs理想主义的平衡：
 * - 不追求完美的理论实现
 * - 关注实际使用中的便利性
 * - 在安全性和易用性之间找平衡
 * - 提供足够但不过度的功能
 * 
 * 学习心得：
 * - 理解了实用主义编程的价值
 * - 学会了从用户角度思考功能设计
 * - 掌握了实际项目中的常见需求
 * - 认识到简单有效比复杂完美更重要
 * - 体会到了用户体验在合约设计中的重要性
 */