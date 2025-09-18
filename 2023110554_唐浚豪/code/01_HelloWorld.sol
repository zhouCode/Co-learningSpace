// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelloWorld - 性能优化版本
 * @author 唐浚豪 (2023110554)
 * @notice 这是一个注重性能优化的HelloWorld合约实现
 * @dev 通过packed结构体、事件优化和gas效率考虑来展示性能优化思维
 * 学习日期: 2024年10月15日
 */
contract HelloWorld {
    // 使用packed结构体减少存储槽位，节省gas
    struct MessageInfo {
        string content;     // 消息内容
        uint32 timestamp;   // 时间戳(uint32足够使用到2106年)
        uint16 version;     // 版本号
        bool isActive;      // 是否激活
    }
    
    // 状态变量优化：将小类型变量打包到同一个存储槽
    address public owner;
    uint32 public messageCount;
    uint16 public contractVersion;
    bool public isPaused;
    
    MessageInfo private currentMessage;
    
    // 事件优化：使用indexed参数提高查询效率
    event MessageUpdated(
        indexed address updater,
        indexed uint32 messageId,
        string newMessage,
        uint32 timestamp
    );
    
    event OwnershipTransferred(
        indexed address previousOwner,
        indexed address newOwner
    );
    
    // 自定义错误，比require字符串更节省gas
    error NotOwner();
    error ContractPaused();
    error EmptyMessage();
    error InvalidAddress();
    
    // 修饰符优化：减少重复的条件检查
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    
    modifier whenNotPaused() {
        if (isPaused) revert ContractPaused();
        _;
    }
    
    /**
     * @dev 构造函数优化：一次性初始化所有状态变量
     * @param _initialMessage 初始消息内容
     */
    constructor(string memory _initialMessage) {
        owner = msg.sender;
        contractVersion = 1;
        messageCount = 1;
        isPaused = false;
        
        // 一次性设置消息信息，减少多次存储操作
        currentMessage = MessageInfo({
            content: _initialMessage,
            timestamp: uint32(block.timestamp),
            version: 1,
            isActive: true
        });
        
        emit MessageUpdated(msg.sender, messageCount, _initialMessage, uint32(block.timestamp));
    }
    
    /**
     * @dev 获取当前消息 - 使用memory返回减少gas消耗
     * @return message 当前消息内容
     * @return timestamp 消息时间戳
     * @return version 消息版本
     */
    function getMessage() external view returns (
        string memory message,
        uint32 timestamp,
        uint16 version
    ) {
        MessageInfo memory info = currentMessage;
        return (info.content, info.timestamp, info.version);
    }
    
    /**
     * @dev 更新消息 - 批量更新减少存储操作
     * @param _newMessage 新的消息内容
     */
    function updateMessage(string calldata _newMessage) 
        external 
        onlyOwner 
        whenNotPaused 
    {
        if (bytes(_newMessage).length == 0) revert EmptyMessage();
        
        // 使用unchecked块优化计数器递增
        unchecked {
            ++messageCount;
        }
        
        // 批量更新结构体，减少存储操作次数
        currentMessage.content = _newMessage;
        currentMessage.timestamp = uint32(block.timestamp);
        currentMessage.version = currentMessage.version + 1;
        
        emit MessageUpdated(msg.sender, messageCount, _newMessage, uint32(block.timestamp));
    }
    
    /**
     * @dev 转移所有权 - 优化的所有权转移
     * @param _newOwner 新所有者地址
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert InvalidAddress();
        
        address previousOwner = owner;
        owner = _newOwner;
        
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
    
    /**
     * @dev 暂停/恢复合约 - 紧急控制功能
     */
    function togglePause() external onlyOwner {
        isPaused = !isPaused;
    }
    
    /**
     * @dev 获取合约统计信息 - 一次调用获取多个信息
     * @return _owner 合约所有者
     * @return _messageCount 消息总数
     * @return _version 合约版本
     * @return _paused 是否暂停
     */
    function getContractInfo() external view returns (
        address _owner,
        uint32 _messageCount,
        uint16 _version,
        bool _paused
    ) {
        return (owner, messageCount, contractVersion, isPaused);
    }
}

/**
 * 个人学习笔记 - 唐浚豪
 * 
 * 性能优化要点总结：
 * 1. 存储优化：使用packed结构体和合理的数据类型大小
 * 2. Gas优化：自定义错误替代require，unchecked算术运算
 * 3. 事件优化：合理使用indexed参数提高查询效率
 * 4. 批量操作：减少多次存储写入，一次性更新多个字段
 * 5. 修饰符优化：避免重复的条件检查逻辑
 * 
 * 学习心得：
 * - 在Solidity中，每个存储操作都消耗大量gas，因此要尽量减少存储写入次数
 * - 使用适当大小的数据类型可以实现存储槽位的打包，显著节省gas
 * - 自定义错误不仅节省gas，还提供了更好的错误处理体验
 * - 性能优化需要在代码可读性和gas效率之间找到平衡点
 */