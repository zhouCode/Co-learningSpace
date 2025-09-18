// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelloWorld - 理论基础扎实版本
 * @author 朱海涛 (2023110571)
 * @notice 基于Solidity语言设计哲学和智能合约理论的HelloWorld实现
 * @dev 深入理解EVM执行模型、状态管理和合约生命周期的示例合约
 * 学习日期: 2024年10月15日
 */

/**
 * @dev 接口定义 - 体现面向接口编程的设计理念
 * 基于Liskov替换原则，任何实现此接口的合约都应该能够替换使用
 */
interface IMessageContract {
    /// @notice 获取当前消息内容
    /// @return message 当前存储的消息字符串
    function getMessage() external view returns (string memory message);
    
    /// @notice 更新消息内容
    /// @param newMessage 新的消息内容
    /// @dev 必须触发MessageUpdated事件
    function updateMessage(string calldata newMessage) external;
    
    /// @notice 消息更新事件
    /// @param oldMessage 旧消息内容
    /// @param newMessage 新消息内容
    /// @param updater 更新者地址
    /// @param timestamp 更新时间戳
    event MessageUpdated(
        string oldMessage,
        string newMessage,
        address indexed updater,
        uint256 timestamp
    );
}

/**
 * @dev 抽象合约 - 定义通用的所有权管理模式
 * 基于开闭原则，对扩展开放，对修改封闭
 */
abstract contract Ownable {
    address private _owner;
    
    /// @notice 所有权转移事件
    /// @param previousOwner 前任所有者
    /// @param newOwner 新所有者
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    
    /// @dev 构造函数设置初始所有者
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /// @notice 获取当前所有者
    /// @return 所有者地址
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    /// @dev 仅所有者修饰符
    /// @notice 限制函数只能由所有者调用
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    
    /// @notice 放弃所有权
    /// @dev 将所有者设置为零地址，不可逆操作
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    /// @notice 转移所有权
    /// @param newOwner 新所有者地址
    /// @dev 新所有者不能是零地址
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    
    /// @dev 内部所有权转移函数
    /// @param newOwner 新所有者地址
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title HelloWorld合约实现
 * @dev 继承Ownable抽象合约并实现IMessageContract接口
 * 体现了继承、多态和接口实现的面向对象设计原则
 */
contract HelloWorld is Ownable, IMessageContract {
    /// @dev 状态变量 - 存储在合约的存储槽中
    /// 根据Solidity存储布局规则，string类型占用动态存储槽
    string private _message;
    
    /// @dev 消息历史记录 - 体现状态变化的可追溯性
    /// 使用动态数组存储历史消息，展示Solidity的数据结构特性
    string[] private _messageHistory;
    
    /// @dev 消息统计信息
    /// 使用结构体组织相关数据，体现数据封装原则
    struct MessageStats {
        uint256 totalUpdates;      // 总更新次数
        uint256 lastUpdateTime;    // 最后更新时间
        address lastUpdater;       // 最后更新者
        uint256 averageLength;     // 平均消息长度
    }
    
    MessageStats private _stats;
    
    /// @dev 访问控制映射 - 实现基于角色的访问控制(RBAC)
    mapping(address => bool) private _authorizedUpdaters;
    
    /// @notice 授权更新者事件
    event UpdaterAuthorized(address indexed updater, bool authorized);
    
    /// @dev 自定义错误 - Solidity 0.8.4+的错误处理机制
    /// 相比require字符串，自定义错误更节省gas且提供更好的调试信息
    error EmptyMessage();
    error UnauthorizedUpdater(address caller);
    error MessageTooLong(uint256 length, uint256 maxLength);
    
    /// @dev 常量定义 - 编译时确定的不可变值
    uint256 public constant MAX_MESSAGE_LENGTH = 1000;
    string public constant CONTRACT_VERSION = "1.0.0";
    
    /**
     * @dev 构造函数 - 合约部署时执行的初始化逻辑
     * @param initialMessage 初始消息内容
     * @notice 构造函数体现了合约的初始化模式
     */
    constructor(string memory initialMessage) {
        // 输入验证 - 防御性编程原则
        if (bytes(initialMessage).length == 0) {
            revert EmptyMessage();
        }
        if (bytes(initialMessage).length > MAX_MESSAGE_LENGTH) {
            revert MessageTooLong(bytes(initialMessage).length, MAX_MESSAGE_LENGTH);
        }
        
        // 状态初始化
        _message = initialMessage;
        _messageHistory.push(initialMessage);
        
        // 统计信息初始化
        _stats = MessageStats({
            totalUpdates: 1,
            lastUpdateTime: block.timestamp,
            lastUpdater: msg.sender,
            averageLength: bytes(initialMessage).length
        });
        
        // 授权部署者为更新者
        _authorizedUpdaters[msg.sender] = true;
        
        // 触发事件 - 记录合约状态变化
        emit MessageUpdated("", initialMessage, msg.sender, block.timestamp);
        emit UpdaterAuthorized(msg.sender, true);
    }
    
    /**
     * @notice 实现IMessageContract接口的getMessage函数
     * @return message 当前消息内容
     * @dev view函数不修改状态，符合函数式编程的纯函数概念
     */
    function getMessage() external view override returns (string memory message) {
        return _message;
    }
    
    /**
     * @notice 实现IMessageContract接口的updateMessage函数
     * @param newMessage 新消息内容
     * @dev 体现了状态变更的原子性和一致性
     */
    function updateMessage(string calldata newMessage) external override {
        // 访问控制检查
        if (!_authorizedUpdaters[msg.sender] && msg.sender != owner()) {
            revert UnauthorizedUpdater(msg.sender);
        }
        
        // 输入验证
        if (bytes(newMessage).length == 0) {
            revert EmptyMessage();
        }
        if (bytes(newMessage).length > MAX_MESSAGE_LENGTH) {
            revert MessageTooLong(bytes(newMessage).length, MAX_MESSAGE_LENGTH);
        }
        
        // 状态变更前的数据保存
        string memory oldMessage = _message;
        
        // 执行状态变更
        _message = newMessage;
        _messageHistory.push(newMessage);
        
        // 更新统计信息
        _updateStats(newMessage);
        
        // 触发事件 - 确保状态变更的可观测性
        emit MessageUpdated(oldMessage, newMessage, msg.sender, block.timestamp);
    }
    
    /**
     * @notice 授权或取消授权更新者
     * @param updater 更新者地址
     * @param authorized 是否授权
     * @dev 仅所有者可调用，体现了权限分离原则
     */
    function setUpdaterAuthorization(address updater, bool authorized) external onlyOwner {
        require(updater != address(0), "Invalid updater address");
        
        _authorizedUpdaters[updater] = authorized;
        emit UpdaterAuthorized(updater, authorized);
    }
    
    /**
     * @notice 检查地址是否为授权更新者
     * @param updater 待检查的地址
     * @return 是否为授权更新者
     */
    function isAuthorizedUpdater(address updater) external view returns (bool) {
        return _authorizedUpdaters[updater];
    }
    
    /**
     * @notice 获取消息历史记录
     * @return 历史消息数组
     * @dev 返回动态数组，展示Solidity的内存管理
     */
    function getMessageHistory() external view returns (string[] memory) {
        return _messageHistory;
    }
    
    /**
     * @notice 获取消息统计信息
     * @return stats 统计信息结构体
     */
    function getMessageStats() external view returns (MessageStats memory stats) {
        return _stats;
    }
    
    /**
     * @notice 获取历史消息数量
     * @return 历史消息总数
     */
    function getHistoryCount() external view returns (uint256) {
        return _messageHistory.length;
    }
    
    /**
     * @dev 内部函数 - 更新统计信息
     * @param newMessage 新消息内容
     * @notice 体现了代码复用和模块化设计
     */
    function _updateStats(string memory newMessage) private {
        _stats.totalUpdates += 1;
        _stats.lastUpdateTime = block.timestamp;
        _stats.lastUpdater = msg.sender;
        
        // 计算平均长度 - 展示算术运算在智能合约中的应用
        uint256 totalLength = _stats.averageLength * (_stats.totalUpdates - 1) + bytes(newMessage).length;
        _stats.averageLength = totalLength / _stats.totalUpdates;
    }
    
    /**
     * @notice 支持ERC165标准的接口检测
     * @param interfaceId 接口标识符
     * @return 是否支持该接口
     * @dev 体现了标准化和互操作性设计
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IMessageContract).interfaceId ||
               interfaceId == 0x01ffc9a7; // ERC165标准接口ID
    }
}

/**
 * 个人学习笔记 - 朱海涛
 * 
 * Solidity语言设计哲学深度分析：
 * 1. 状态机模型：智能合约本质上是一个状态机，每次交易都是状态转换
 * 2. 确定性执行：相同输入必须产生相同输出，保证区块链的一致性
 * 3. Gas机制：通过经济激励确保计算资源的合理使用
 * 4. 不可变性：合约代码部署后不可修改，体现了区块链的不可篡改特性
 * 
 * 面向对象设计原则在Solidity中的应用：
 * - 单一职责原则：每个合约和函数都有明确的职责
 * - 开闭原则：通过继承和接口实现扩展而非修改
 * - 里氏替换原则：子合约可以替换父合约使用
 * - 接口隔离原则：定义最小化的接口
 * - 依赖倒置原则：依赖抽象而非具体实现
 * 
 * EVM执行模型理解：
 * - 栈式虚拟机：操作数通过栈进行传递
 * - 存储模型：storage、memory、calldata的区别和使用场景
 * - Gas计算：不同操作的gas消耗及优化策略
 * - 事件机制：通过日志实现链下监听和查询
 * 
 * 学习收获：
 * - 深入理解了智能合约的理论基础和设计模式
 * - 掌握了Solidity语言的高级特性和最佳实践
 * - 学会了如何将传统软件工程原则应用到区块链开发中
 * - 理解了去中心化应用的架构设计和安全考虑
 */