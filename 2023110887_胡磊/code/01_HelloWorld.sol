// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 创新型HelloWorld合约
 * @dev 融合多种创新特性的智能合约
 * @author 胡磊 (2023110887)
 * @notice 这个合约展示了创新的合约设计思路
 */
contract InnovativeHelloWorld {
    // 创新特性：多语言支持
    mapping(string => string) public greetings;
    mapping(address => string) public userLanguages;
    
    // 创新特性：情感状态系统
    enum Mood { Happy, Excited, Calm, Energetic }
    mapping(address => Mood) public userMoods;
    
    // 创新特性：互动计数器
    mapping(address => uint256) public interactionCount;
    uint256 public totalInteractions;
    
    // 创新特性：时间敏感问候
    mapping(uint256 => string) public timeBasedGreetings;
    
    // 事件系统
    event GreetingChanged(address indexed user, string language, string greeting);
    event MoodUpdated(address indexed user, Mood newMood);
    event InteractionRecorded(address indexed user, uint256 count);
    
    constructor() {
        // 初始化多语言问候语
        greetings["en"] = "Hello, Blockchain World!";
        greetings["zh"] = "你好，区块链世界！";
        greetings["ja"] = "こんにちは、ブロックチェーンの世界！";
        greetings["ko"] = "안녕하세요, 블록체인 세계!";
        greetings["fr"] = "Bonjour, Monde Blockchain!";
        
        // 初始化时间问候语
        timeBasedGreetings[6] = "Good Morning, Early Bird!";
        timeBasedGreetings[12] = "Good Afternoon, Blockchain Explorer!";
        timeBasedGreetings[18] = "Good Evening, Code Warrior!";
        timeBasedGreetings[22] = "Good Night, Dream of Smart Contracts!";
    }
    
    /**
     * @dev 智能问候函数 - 根据用户偏好和时间返回个性化问候
     */
    function getSmartGreeting() public returns (string memory) {
        address user = msg.sender;
        interactionCount[user]++;
        totalInteractions++;
        
        // 获取用户语言偏好
        string memory userLang = bytes(userLanguages[user]).length > 0 
            ? userLanguages[user] 
            : "en";
        
        // 获取基础问候语
        string memory baseGreeting = bytes(greetings[userLang]).length > 0 
            ? greetings[userLang] 
            : greetings["en"];
        
        // 根据心情添加表情符号
        string memory moodEmoji = getMoodEmoji(userMoods[user]);
        
        // 根据互动次数添加个性化内容
        string memory personalTouch = getPersonalTouch(interactionCount[user]);
        
        emit InteractionRecorded(user, interactionCount[user]);
        
        return string(abi.encodePacked(baseGreeting, " ", moodEmoji, " ", personalTouch));
    }
    
    /**
     * @dev 设置用户语言偏好
     */
    function setLanguage(string memory _language) public {
        require(bytes(greetings[_language]).length > 0, "Language not supported");
        userLanguages[msg.sender] = _language;
        emit GreetingChanged(msg.sender, _language, greetings[_language]);
    }
    
    /**
     * @dev 设置用户心情
     */
    function setMood(Mood _mood) public {
        userMoods[msg.sender] = _mood;
        emit MoodUpdated(msg.sender, _mood);
    }
    
    /**
     * @dev 添加新的语言支持（创新的众包翻译功能）
     */
    function addLanguage(string memory _langCode, string memory _greeting) public {
        require(bytes(_langCode).length > 0, "Language code cannot be empty");
        require(bytes(_greeting).length > 0, "Greeting cannot be empty");
        
        greetings[_langCode] = _greeting;
        emit GreetingChanged(msg.sender, _langCode, _greeting);
    }
    
    /**
     * @dev 获取心情表情符号
     */
    function getMoodEmoji(Mood _mood) internal pure returns (string memory) {
        if (_mood == Mood.Happy) return "😊";
        if (_mood == Mood.Excited) return "🚀";
        if (_mood == Mood.Calm) return "🧘";
        if (_mood == Mood.Energetic) return "⚡";
        return "🤖";
    }
    
    /**
     * @dev 根据互动次数生成个性化内容
     */
    function getPersonalTouch(uint256 _count) internal pure returns (string memory) {
        if (_count == 1) return "(Welcome, newcomer!)";
        if (_count <= 5) return "(Getting familiar!)";
        if (_count <= 10) return "(Regular visitor!)";
        if (_count <= 50) return "(Blockchain enthusiast!)";
        return "(Master of the chain!)";
    }
    
    /**
     * @dev 获取基于时间的问候语
     */
    function getTimeBasedGreeting() public view returns (string memory) {
        uint256 hour = (block.timestamp / 3600) % 24;
        
        if (hour < 6) return timeBasedGreetings[22];
        if (hour < 12) return timeBasedGreetings[6];
        if (hour < 18) return timeBasedGreeting[12];
        return timeBasedGreetings[18];
    }
    
    /**
     * @dev 获取用户统计信息
     */
    function getUserStats(address _user) public view returns (
        string memory language,
        Mood mood,
        uint256 interactions,
        string memory favoriteGreeting
    ) {
        language = userLanguages[_user];
        mood = userMoods[_user];
        interactions = interactionCount[_user];
        favoriteGreeting = bytes(language).length > 0 ? greetings[language] : greetings["en"];
    }
    
    /**
     * @dev 获取全局统计
     */
    function getGlobalStats() public view returns (
        uint256 totalUsers,
        uint256 totalInteractions_,
        uint256 supportedLanguages
    ) {
        // 这里简化实现，实际项目中需要更复杂的统计逻辑
        totalInteractions_ = totalInteractions;
        supportedLanguages = 5; // 当前支持的语言数量
        // totalUsers 需要额外的数据结构来跟踪
    }
}

/*
创新设计思路总结：

1. 多语言支持系统
   - 动态语言切换
   - 众包翻译功能
   - 文化适应性设计

2. 情感交互系统
   - 心情状态管理
   - 表情符号集成
   - 个性化体验

3. 智能适应机制
   - 基于使用频率的个性化
   - 时间敏感的问候语
   - 用户行为分析

4. 社区驱动特性
   - 用户贡献内容
   - 统计数据透明化
   - 互动激励机制

5. 扩展性设计
   - 模块化功能
   - 可插拔组件
   - 未来功能预留

这种设计体现了Web3时代的用户中心化思维，
将传统的静态合约转变为动态、互动的智能系统。
*/