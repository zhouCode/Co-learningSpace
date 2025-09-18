// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelloWorld - 优雅简洁的智能合约
 * @dev 体现优雅编程风格和简洁设计理念的Hello World实现
 * @author 曾月 (2023111492)
 * 
 * 设计特色：
 * 1. 优雅的代码结构：清晰的层次、优美的命名、简洁的逻辑
 * 2. 简洁的设计理念：最小化复杂度、专注核心功能、避免过度设计
 * 3. 美学导向：代码如诗、结构如画、逻辑如歌
 * 4. 禅意编程：少即是多、简即是美、静即是动
 */

// ============================================================================
// 优雅的接口设计
// ============================================================================

/**
 * @dev 简洁优雅的问候接口
 */
interface IElegantGreeting {
    /// @dev 获取问候语
    function getGreeting() external view returns (string memory);
    
    /// @dev 设置个性化问候
    function setPersonalGreeting(string memory greeting) external;
    
    /// @dev 获取问候历史
    function getGreetingHistory() external view returns (string[] memory);
}

/**
 * @dev 优雅的事件接口
 */
interface IElegantEvents {
    /// @dev 问候事件
    event Greeted(address indexed greeter, string message, uint256 timestamp);
    
    /// @dev 个性化问候事件
    event PersonalGreetingSet(address indexed user, string greeting);
    
    /// @dev 智慧分享事件
    event WisdomShared(address indexed sharer, string wisdom);
}

// ============================================================================
// 优雅的工具库
// ============================================================================

/**
 * @dev 优雅字符串处理库
 */
library ElegantStrings {
    /**
     * @dev 优雅地连接字符串
     */
    function elegantConcat(
        string memory a,
        string memory b
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, " ", b));
    }
    
    /**
     * @dev 检查字符串是否为空
     */
    function isEmpty(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
    
    /**
     * @dev 优雅地格式化问候语
     */
    function formatGreeting(
        string memory greeting,
        address user
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            "🌸 ",
            greeting,
            ", dear ",
            _addressToString(user),
            " 🌸"
        ));
    }
    
    /**
     * @dev 将地址转换为优雅的字符串表示
     */
    function _addressToString(address addr) private pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(8); // 只显示前4字节，保持简洁
        
        for (uint256 i = 0; i < 4; i++) {
            str[i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[i * 2 + 1] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        
        return string(abi.encodePacked("0x", str, "..."));
    }
}

/**
 * @dev 优雅时间处理库
 */
library ElegantTime {
    /**
     * @dev 获取优雅的时间问候
     */
    function getTimeBasedGreeting() internal view returns (string memory) {
        uint256 hour = (block.timestamp / 3600) % 24;
        
        if (hour < 6) {
            return "Good night, dreamer";
        } else if (hour < 12) {
            return "Good morning, sunshine";
        } else if (hour < 18) {
            return "Good afternoon, friend";
        } else {
            return "Good evening, star";
        }
    }
    
    /**
     * @dev 获取诗意的时间描述
     */
    function getPoeticalTime() internal view returns (string memory) {
        uint256 hour = (block.timestamp / 3600) % 24;
        
        if (hour < 6) {
            return "in the quiet hours of night";
        } else if (hour < 12) {
            return "as the morning dew glistens";
        } else if (hour < 18) {
            return "under the warm afternoon sun";
        } else {
            return "beneath the evening stars";
        }
    }
}

// ============================================================================
// 主合约：优雅的Hello World
// ============================================================================

contract HelloWorld is IElegantGreeting, IElegantEvents {
    using ElegantStrings for string;
    using ElegantTime for uint256;
    
    // ========================================================================
    // 优雅的状态变量
    // ========================================================================
    
    /// @dev 合约的诗意名称
    string public constant POETIC_NAME = "Elegant Greetings Garden";
    
    /// @dev 合约版本，体现迭代之美
    string public constant VERSION = "1.0.0 - Zen";
    
    /// @dev 默认问候语，简洁而温暖
    string private constant DEFAULT_GREETING = "Hello, Beautiful World";
    
    /// @dev 合约创建者，第一个问候者
    address public immutable creator;
    
    /// @dev 合约诞生时刻
    uint256 public immutable birthTime;
    
    /// @dev 总问候次数，记录美好时刻
    uint256 public totalGreetings;
    
    /// @dev 个性化问候映射
    mapping(address => string) private personalGreetings;
    
    /// @dev 问候历史，保存美好回忆
    string[] private greetingHistory;
    
    /// @dev 用户问候次数
    mapping(address => uint256) public userGreetingCount;
    
    /// @dev 智慧语录集合
    string[] private wisdomCollection;
    
    /// @dev 活跃用户列表
    address[] private activeUsers;
    
    /// @dev 用户是否已记录
    mapping(address => bool) private isUserRecorded;
    
    // ========================================================================
    // 优雅的修饰符
    // ========================================================================
    
    /// @dev 确保问候语不为空
    modifier nonEmptyGreeting(string memory greeting) {
        require(!greeting.isEmpty(), "Greeting cannot be empty, like a silent heart");
        _;
    }
    
    /// @dev 记录用户活动
    modifier recordActivity() {
        if (!isUserRecorded[msg.sender]) {
            activeUsers.push(msg.sender);
            isUserRecorded[msg.sender] = true;
        }
        _;
    }
    
    // ========================================================================
    // 构造函数：优雅的诞生
    // ========================================================================
    
    constructor() {
        creator = msg.sender;
        birthTime = block.timestamp;
        
        // 初始化智慧语录
        _initializeWisdom();
        
        // 创建者的第一声问候
        _greet(DEFAULT_GREETING);
        
        emit Greeted(msg.sender, DEFAULT_GREETING, block.timestamp);
    }
    
    // ========================================================================
    // 核心功能：优雅的问候
    // ========================================================================
    
    /**
     * @dev 获取当前问候语，融合时间与个性
     */
    function getGreeting() external view override returns (string memory) {
        string memory personalGreeting = personalGreetings[msg.sender];
        
        if (!personalGreeting.isEmpty()) {
            return ElegantStrings.formatGreeting(personalGreeting, msg.sender);
        }
        
        string memory timeGreeting = ElegantTime.getTimeBasedGreeting();
        return ElegantStrings.formatGreeting(timeGreeting, msg.sender);
    }
    
    /**
     * @dev 设置个性化问候，表达独特的自我
     */
    function setPersonalGreeting(
        string memory greeting
    ) external override nonEmptyGreeting(greeting) recordActivity {
        personalGreetings[msg.sender] = greeting;
        _greet(greeting);
        
        emit PersonalGreetingSet(msg.sender, greeting);
        emit Greeted(msg.sender, greeting, block.timestamp);
    }
    
    /**
     * @dev 获取问候历史，回味美好时光
     */
    function getGreetingHistory() external view override returns (string[] memory) {
        return greetingHistory;
    }
    
    /**
     * @dev 简单的问候功能
     */
    function sayHello() external recordActivity returns (string memory) {
        string memory greeting = ElegantTime.getTimeBasedGreeting();
        _greet(greeting);
        
        emit Greeted(msg.sender, greeting, block.timestamp);
        return ElegantStrings.formatGreeting(greeting, msg.sender);
    }
    
    /**
     * @dev 分享智慧语录
     */
    function shareWisdom(string memory wisdom) external nonEmptyGreeting(wisdom) recordActivity {
        wisdomCollection.push(wisdom);
        emit WisdomShared(msg.sender, wisdom);
    }
    
    /**
     * @dev 获取随机智慧语录
     */
    function getRandomWisdom() external view returns (string memory) {
        if (wisdomCollection.length == 0) {
            return "Wisdom comes from within, like morning dew on petals.";
        }
        
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            msg.sender
        ))) % wisdomCollection.length;
        
        return wisdomCollection[randomIndex];
    }
    
    // ========================================================================
    // 优雅的查询功能
    // ========================================================================
    
    /**
     * @dev 获取合约的诗意状态
     */
    function getContractPoetry() external view returns (
        string memory name,
        string memory version,
        uint256 age,
        uint256 greetings,
        uint256 activeUserCount,
        string memory timeDescription
    ) {
        return (
            POETIC_NAME,
            VERSION,
            block.timestamp - birthTime,
            totalGreetings,
            activeUsers.length,
            ElegantTime.getPoeticalTime()
        );
    }
    
    /**
     * @dev 获取用户的问候足迹
     */
    function getUserFootprint(address user) external view returns (
        uint256 greetingCount,
        string memory personalGreeting,
        bool isActive
    ) {
        return (
            userGreetingCount[user],
            personalGreetings[user],
            isUserRecorded[user]
        );
    }
    
    /**
     * @dev 获取最近的问候历史
     */
    function getRecentGreetings(uint256 count) external view returns (string[] memory) {
        if (count == 0 || greetingHistory.length == 0) {
            return new string[](0);
        }
        
        uint256 actualCount = count > greetingHistory.length ? greetingHistory.length : count;
        string[] memory recent = new string[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            recent[i] = greetingHistory[greetingHistory.length - 1 - i];
        }
        
        return recent;
    }
    
    /**
     * @dev 获取智慧语录集合
     */
    function getAllWisdom() external view returns (string[] memory) {
        return wisdomCollection;
    }
    
    /**
     * @dev 获取活跃用户列表
     */
    function getActiveUsers() external view returns (address[] memory) {
        return activeUsers;
    }
    
    // ========================================================================
    // 内部辅助函数：优雅的实现
    // ========================================================================
    
    /**
     * @dev 内部问候处理，优雅而简洁
     */
    function _greet(string memory greeting) private {
        totalGreetings++;
        userGreetingCount[msg.sender]++;
        
        // 保持历史记录简洁，最多保存100条
        if (greetingHistory.length >= 100) {
            // 移除最旧的记录
            for (uint256 i = 0; i < greetingHistory.length - 1; i++) {
                greetingHistory[i] = greetingHistory[i + 1];
            }
            greetingHistory[greetingHistory.length - 1] = greeting;
        } else {
            greetingHistory.push(greeting);
        }
    }
    
    /**
     * @dev 初始化智慧语录，播种美好
     */
    function _initializeWisdom() private {
        wisdomCollection.push("Simplicity is the ultimate sophistication.");
        wisdomCollection.push("In the depth of winter, I finally learned that there was in me an invincible summer.");
        wisdomCollection.push("The best way to find out if you can trust somebody is to trust them.");
        wisdomCollection.push("Be yourself; everyone else is already taken.");
        wisdomCollection.push("Code is poetry, and poetry is the language of the soul.");
        wisdomCollection.push("Elegance is not about being noticed, it's about being remembered.");
        wisdomCollection.push("Less is more, but better is everything.");
        wisdomCollection.push("Beauty lies in the harmony of function and form.");
    }
    
    // ========================================================================
    // 特殊功能：优雅的交互
    // ========================================================================
    
    /**
     * @dev 创建诗意的问候
     */
    function createPoeticGreeting(
        string memory emotion,
        string memory element
    ) external view returns (string memory) {
        return string(abi.encodePacked(
            "Like ",
            element,
            " dancing with ",
            emotion,
            ", ",
            ElegantTime.getPoeticalTime(),
            ", I greet you with warmth."
        ));
    }
    
    /**
     * @dev 获取合约的生命力指标
     */
    function getVitality() external view returns (
        uint256 energy,      // 基于问候频率
        uint256 diversity,   // 基于用户多样性
        uint256 wisdom,      // 基于智慧语录数量
        string memory mood   // 合约的当前"心情"
    ) {
        energy = totalGreetings;
        diversity = activeUsers.length;
        wisdom = wisdomCollection.length;
        
        // 根据活跃度确定"心情"
        if (totalGreetings > 100) {
            mood = "Joyful and vibrant";
        } else if (totalGreetings > 50) {
            mood = "Content and peaceful";
        } else if (totalGreetings > 10) {
            mood = "Gentle and welcoming";
        } else {
            mood = "Quiet and contemplative";
        }
        
        return (energy, diversity, wisdom, mood);
    }
    
    /**
     * @dev 优雅的告别功能
     */
    function sayGoodbye() external view returns (string memory) {
        return string(abi.encodePacked(
            "Until we meet again, ",
            ElegantStrings._addressToString(msg.sender),
            ". May your journey be filled with beauty and wonder. 🌙✨"
        ));
    }
}

/**
 * 设计特色总结：
 * 
 * 1. 优雅的代码结构：
 *    - 清晰的模块划分和层次结构
 *    - 优美的命名约定和注释风格
 *    - 简洁的逻辑流程和函数设计
 *    - 诗意的变量名和常量定义
 * 
 * 2. 简洁的设计理念：
 *    - 最小化复杂度，专注核心功能
 *    - 避免过度设计，保持功能纯粹
 *    - 优雅的错误处理和边界条件
 *    - 简洁而富有表现力的接口
 * 
 * 3. 美学导向的编程：
 *    - 代码如诗，结构如画
 *    - 函数命名体现诗意和美感
 *    - 注释风格优雅而富有哲理
 *    - 整体设计体现和谐之美
 * 
 * 4. 禅意编程哲学：
 *    - 少即是多的设计原则
 *    - 简即是美的实现方式
 *    - 静中有动的交互设计
 *    - 内在智慧的外在表达
 * 
 * 这个合约展现了对编程美学的深刻理解，
 * 将技术实现与艺术表达完美融合，
 * 体现了优雅简洁的编程风格。
 */