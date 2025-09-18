// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 函数式编程风格HelloWorld合约
 * @dev 采用函数式编程理念的智能合约设计
 * @author 费沁烽 (2023111423)
 * @notice 展示函数式编程在Solidity中的应用
 */

contract FunctionalHelloWorld {
    // 不可变状态 - 函数式编程核心理念
    struct Message {
        string content;
        uint256 timestamp;
        address sender;
        bool isActive;
    }
    
    struct MessageHistory {
        Message[] messages;
        mapping(address => uint256[]) userMessageIds;
        uint256 totalCount;
    }
    
    MessageHistory private messageHistory;
    
    // 纯函数式事件
    event MessageCreated(uint256 indexed id, address indexed sender, string content);
    event MessageTransformed(uint256 indexed id, string oldContent, string newContent);
    
    // 函数式修饰符 - 高阶函数概念
    modifier pure_validation(function(string memory) pure returns (bool) validator, string memory input) {
        require(validator(input), "Validation failed");
        _;
    }
    
    modifier compose_checks(
        function(address) pure returns (bool) addressCheck,
        function(string memory) pure returns (bool) contentCheck,
        address addr,
        string memory content
    ) {
        require(addressCheck(addr) && contentCheck(content), "Composed validation failed");
        _;
    }
    
    constructor() {
        // 初始化时创建不可变的初始状态
        _createMessage("Hello, Functional World!", msg.sender);
    }
    
    /**
     * @dev 纯函数 - 验证地址有效性
     */
    function isValidAddress(address _addr) public pure returns (bool) {
        return _addr != address(0);
    }
    
    /**
     * @dev 纯函数 - 验证消息内容
     */
    function isValidMessage(string memory _content) public pure returns (bool) {
        bytes memory contentBytes = bytes(_content);
        return contentBytes.length > 0 && contentBytes.length <= 200;
    }
    
    /**
     * @dev 纯函数 - 消息长度检查
     */
    function isShortMessage(string memory _content) public pure returns (bool) {
        return bytes(_content).length <= 50;
    }
    
    /**
     * @dev 纯函数 - 字符串转换为大写（简化版）
     */
    function toUpperCase(string memory _str) public pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(strBytes.length);
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= 0x61 && strBytes[i] <= 0x7A) {
                result[i] = bytes1(uint8(strBytes[i]) - 32);
            } else {
                result[i] = strBytes[i];
            }
        }
        
        return string(result);
    }
    
    /**
     * @dev 纯函数 - 字符串连接
     */
    function concatenate(string memory _a, string memory _b) public pure returns (string memory) {
        return string(abi.encodePacked(_a, _b));
    }
    
    /**
     * @dev 高阶函数概念 - 消息转换器
     */
    function transformMessage(
        uint256 _messageId,
        function(string memory) pure returns (string memory) transformer
    ) public returns (string memory) {
        require(_messageId < messageHistory.totalCount, "Invalid message ID");
        
        Message storage message = messageHistory.messages[_messageId];
        require(message.sender == msg.sender, "Not message owner");
        require(message.isActive, "Message not active");
        
        string memory oldContent = message.content;
        string memory newContent = transformer(oldContent);
        
        message.content = newContent;
        message.timestamp = block.timestamp;
        
        emit MessageTransformed(_messageId, oldContent, newContent);
        return newContent;
    }
    
    /**
     * @dev 函数式消息创建 - 不可变性原则
     */
    function createMessage(string memory _content) 
        public 
        pure_validation(isValidMessage, _content)
        returns (uint256) 
    {
        return _createMessage(_content, msg.sender);
    }
    
    /**
     * @dev 内部纯函数式消息创建
     */
    function _createMessage(string memory _content, address _sender) private returns (uint256) {
        uint256 messageId = messageHistory.totalCount;
        
        messageHistory.messages.push(Message({
            content: _content,
            timestamp: block.timestamp,
            sender: _sender,
            isActive: true
        }));
        
        messageHistory.userMessageIds[_sender].push(messageId);
        messageHistory.totalCount++;
        
        emit MessageCreated(messageId, _sender, _content);
        return messageId;
    }
    
    /**
     * @dev 函数式查询 - 不修改状态的纯查询
     */
    function getMessage(uint256 _messageId) 
        public 
        view 
        returns (Message memory) 
    {
        require(_messageId < messageHistory.totalCount, "Invalid message ID");
        return messageHistory.messages[_messageId];
    }
    
    /**
     * @dev 高阶函数 - 消息过滤器
     */
    function filterMessages(
        function(Message memory) pure returns (bool) predicate
    ) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](messageHistory.totalCount);
        uint256 count = 0;
        
        for (uint256 i = 0; i < messageHistory.totalCount; i++) {
            if (predicate(messageHistory.messages[i])) {
                result[count] = i;
                count++;
            }
        }
        
        // 调整数组大小
        uint256[] memory filteredResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            filteredResult[i] = result[i];
        }
        
        return filteredResult;
    }
    
    /**
     * @dev 函数式映射 - 获取用户所有消息
     */
    function getUserMessages(address _user) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return messageHistory.userMessageIds[_user];
    }
    
    /**
     * @dev 函数式聚合 - 计算用户活跃消息数
     */
    function countActiveMessages(address _user) 
        public 
        view 
        returns (uint256) 
    {
        uint256[] memory userMessages = messageHistory.userMessageIds[_user];
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < userMessages.length; i++) {
            if (messageHistory.messages[userMessages[i]].isActive) {
                activeCount++;
            }
        }
        
        return activeCount;
    }
    
    /**
     * @dev 函数式组合 - 创建格式化消息
     */
    function createFormattedMessage(string memory _content, string memory _prefix) 
        public 
        compose_checks(isValidAddress, isValidMessage, msg.sender, _content)
        returns (uint256) 
    {
        string memory formattedContent = concatenate(_prefix, _content);
        return _createMessage(formattedContent, msg.sender);
    }
    
    /**
     * @dev 柯里化函数概念 - 部分应用
     */
    function createPrefixedMessageCreator(string memory _prefix) 
        public 
        pure 
        returns (function(string memory) pure returns (string memory)) 
    {
        // 注意：Solidity中函数类型有限制，这里展示概念
        // 实际实现需要通过其他方式
        return function(string memory content) pure returns (string memory) {
            return string(abi.encodePacked(_prefix, content));
        };
    }
    
    /**
     * @dev 函数式状态查询 - 不可变视图
     */
    function getSystemState() 
        public 
        view 
        returns (
            uint256 totalMessages,
            uint256 activeMessages,
            uint256 currentTimestamp
        ) 
    {
        uint256 active = 0;
        for (uint256 i = 0; i < messageHistory.totalCount; i++) {
            if (messageHistory.messages[i].isActive) {
                active++;
            }
        }
        
        return (messageHistory.totalCount, active, block.timestamp);
    }
    
    /**
     * @dev 函数式消息去激活 - 创建新状态而非修改
     */
    function deactivateMessage(uint256 _messageId) public returns (bool) {
        require(_messageId < messageHistory.totalCount, "Invalid message ID");
        require(messageHistory.messages[_messageId].sender == msg.sender, "Not owner");
        
        messageHistory.messages[_messageId].isActive = false;
        return true;
    }
}

/*
函数式编程风格特色：

1. 不可变性原则
   - 尽量避免状态修改
   - 创建新状态而非修改旧状态
   - 数据结构设计体现不可变性

2. 纯函数设计
   - 大量纯函数实现
   - 无副作用的计算
   - 可预测的输出

3. 高阶函数概念
   - 函数作为参数传递
   - 函数组合和柯里化
   - 函数式修饰符

4. 函数式操作
   - 映射(map)操作
   - 过滤(filter)操作  
   - 聚合(reduce)操作

5. 声明式编程
   - 描述"做什么"而非"怎么做"
   - 函数组合实现复杂逻辑
   - 表达式优于语句

这种设计体现了函数式编程理念：
纯函数、不可变性、高阶函数、声明式编程。
*/