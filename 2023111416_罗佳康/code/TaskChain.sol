// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TaskChain - 去中心化任务管理系统
 * @dev 实战项目：通过任务管理系统学习Solidity基础语法
 * @author 罗佳康 (2023111416)
 * @notice 这是我的第一个完整Solidity项目，专注于实战应用
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TaskChain is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // 角色定义
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    // 任务状态枚举
    enum TaskStatus {
        CREATED,     // 已创建
        IN_PROGRESS, // 进行中
        COMPLETED,   // 已完成
        VERIFIED,    // 已验证
        REJECTED,    // 已拒绝
        CANCELLED    // 已取消
    }
    
    // 任务优先级
    enum Priority {
        LOW,
        MEDIUM,
        HIGH,
        URGENT
    }
    
    // 任务结构体
    struct Task {
        uint256 id;
        string title;
        string description;
        address creator;
        address assignee;
        uint256 reward;
        uint256 deadline;
        TaskStatus status;
        Priority priority;
        uint256 createdAt;
        uint256 completedAt;
        string[] tags;
        bool isPublic;
    }
    
    // 用户信息结构体
    struct User {
        address userAddress;
        string username;
        uint256 reputation;
        uint256 tasksCreated;
        uint256 tasksCompleted;
        uint256 totalEarned;
        bool isActive;
        uint256 joinedAt;
    }
    
    // 状态变量
    Counters.Counter private _taskIdCounter;
    mapping(uint256 => Task) public tasks;
    mapping(address => User) public users;
    mapping(address => uint256[]) public userTasks; // 用户创建的任务
    mapping(address => uint256[]) public assignedTasks; // 用户被分配的任务
    mapping(uint256 => mapping(address => bool)) public taskApplications; // 任务申请
    mapping(string => uint256[]) public tasksByTag; // 按标签分类的任务
    
    // 系统配置
    uint256 public constant MIN_REWARD = 0.001 ether;
    uint256 public constant MAX_REWARD = 10 ether;
    uint256 public constant PLATFORM_FEE_PERCENT = 5; // 5%平台费用
    uint256 public platformBalance;
    
    // 事件定义
    event TaskCreated(
        uint256 indexed taskId,
        address indexed creator,
        string title,
        uint256 reward,
        uint256 deadline
    );
    
    event TaskAssigned(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 timestamp
    );
    
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed assignee,
        uint256 timestamp
    );
    
    event TaskVerified(
        uint256 indexed taskId,
        address indexed verifier,
        bool approved,
        uint256 timestamp
    );
    
    event RewardPaid(
        uint256 indexed taskId,
        address indexed recipient,
        uint256 amount
    );
    
    event UserRegistered(
        address indexed user,
        string username,
        uint256 timestamp
    );
    
    event ReputationUpdated(
        address indexed user,
        uint256 oldReputation,
        uint256 newReputation
    );
    
    // 修饰符
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isActive, "TaskChain: User not registered");
        _;
    }
    
    modifier validTaskId(uint256 taskId) {
        require(taskId > 0 && taskId <= _taskIdCounter.current(), "TaskChain: Invalid task ID");
        _;
    }
    
    modifier onlyTaskCreator(uint256 taskId) {
        require(tasks[taskId].creator == msg.sender, "TaskChain: Not task creator");
        _;
    }
    
    modifier onlyTaskAssignee(uint256 taskId) {
        require(tasks[taskId].assignee == msg.sender, "TaskChain: Not task assignee");
        _;
    }
    
    modifier validTaskStatus(uint256 taskId, TaskStatus expectedStatus) {
        require(tasks[taskId].status == expectedStatus, "TaskChain: Invalid task status");
        _;
    }
    
    modifier notExpired(uint256 taskId) {
        require(block.timestamp <= tasks[taskId].deadline, "TaskChain: Task expired");
        _;
    }
    
    // 构造函数
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev 用户注册
     * @param username 用户名
     */
    function registerUser(string memory username) external {
        require(!users[msg.sender].isActive, "TaskChain: User already registered");
        require(bytes(username).length > 0, "TaskChain: Username cannot be empty");
        require(bytes(username).length <= 32, "TaskChain: Username too long");
        
        users[msg.sender] = User({
            userAddress: msg.sender,
            username: username,
            reputation: 100, // 初始声誉值
            tasksCreated: 0,
            tasksCompleted: 0,
            totalEarned: 0,
            isActive: true,
            joinedAt: block.timestamp
        });
        
        emit UserRegistered(msg.sender, username, block.timestamp);
    }
    
    /**
     * @dev 创建任务
     * @param title 任务标题
     * @param description 任务描述
     * @param deadline 截止时间
     * @param priority 优先级
     * @param tags 标签数组
     * @param isPublic 是否公开
     */
    function createTask(
        string memory title,
        string memory description,
        uint256 deadline,
        Priority priority,
        string[] memory tags,
        bool isPublic
    ) external payable onlyRegisteredUser nonReentrant {
        require(bytes(title).length > 0, "TaskChain: Title cannot be empty");
        require(bytes(description).length > 0, "TaskChain: Description cannot be empty");
        require(deadline > block.timestamp, "TaskChain: Invalid deadline");
        require(msg.value >= MIN_REWARD, "TaskChain: Reward too low");
        require(msg.value <= MAX_REWARD, "TaskChain: Reward too high");
        require(tags.length <= 5, "TaskChain: Too many tags");
        
        _taskIdCounter.increment();
        uint256 taskId = _taskIdCounter.current();
        
        tasks[taskId] = Task({
            id: taskId,
            title: title,
            description: description,
            creator: msg.sender,
            assignee: address(0),
            reward: msg.value,
            deadline: deadline,
            status: TaskStatus.CREATED,
            priority: priority,
            createdAt: block.timestamp,
            completedAt: 0,
            tags: tags,
            isPublic: isPublic
        });
        
        // 更新用户统计
        users[msg.sender].tasksCreated++;
        userTasks[msg.sender].push(taskId);
        
        // 按标签分类
        for (uint256 i = 0; i < tags.length; i++) {
            tasksByTag[tags[i]].push(taskId);
        }
        
        emit TaskCreated(taskId, msg.sender, title, msg.value, deadline);
    }
    
    /**
     * @dev 申请任务
     * @param taskId 任务ID
     */
    function applyForTask(uint256 taskId) 
        external 
        onlyRegisteredUser 
        validTaskId(taskId) 
        validTaskStatus(taskId, TaskStatus.CREATED)
        notExpired(taskId)
    {
        require(tasks[taskId].creator != msg.sender, "TaskChain: Cannot apply for own task");
        require(!taskApplications[taskId][msg.sender], "TaskChain: Already applied");
        require(tasks[taskId].isPublic, "TaskChain: Task is not public");
        
        taskApplications[taskId][msg.sender] = true;
    }
    
    /**
     * @dev 分配任务
     * @param taskId 任务ID
     * @param assignee 被分配者地址
     */
    function assignTask(uint256 taskId, address assignee) 
        external 
        onlyTaskCreator(taskId)
        validTaskId(taskId)
        validTaskStatus(taskId, TaskStatus.CREATED)
        notExpired(taskId)
    {
        require(users[assignee].isActive, "TaskChain: Assignee not registered");
        require(assignee != msg.sender, "TaskChain: Cannot assign to self");
        
        if (tasks[taskId].isPublic) {
            require(taskApplications[taskId][assignee], "TaskChain: User has not applied");
        }
        
        tasks[taskId].assignee = assignee;
        tasks[taskId].status = TaskStatus.IN_PROGRESS;
        assignedTasks[assignee].push(taskId);
        
        emit TaskAssigned(taskId, assignee, block.timestamp);
    }
    
    /**
     * @dev 完成任务
     * @param taskId 任务ID
     */
    function completeTask(uint256 taskId) 
        external 
        onlyTaskAssignee(taskId)
        validTaskId(taskId)
        validTaskStatus(taskId, TaskStatus.IN_PROGRESS)
        notExpired(taskId)
    {
        tasks[taskId].status = TaskStatus.COMPLETED;
        tasks[taskId].completedAt = block.timestamp;
        
        emit TaskCompleted(taskId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev 验证任务
     * @param taskId 任务ID
     * @param approved 是否通过
     */
    function verifyTask(uint256 taskId, bool approved) 
        external 
        onlyRole(VERIFIER_ROLE)
        validTaskId(taskId)
        validTaskStatus(taskId, TaskStatus.COMPLETED)
        nonReentrant
    {
        Task storage task = tasks[taskId];
        
        if (approved) {
            task.status = TaskStatus.VERIFIED;
            
            // 计算平台费用
            uint256 platformFee = (task.reward * PLATFORM_FEE_PERCENT) / 100;
            uint256 userReward = task.reward - platformFee;
            
            // 更新平台余额
            platformBalance += platformFee;
            
            // 支付奖励
            payable(task.assignee).transfer(userReward);
            
            // 更新用户统计和声誉
            users[task.assignee].tasksCompleted++;
            users[task.assignee].totalEarned += userReward;
            _updateReputation(task.assignee, true);
            _updateReputation(task.creator, true);
            
            emit RewardPaid(taskId, task.assignee, userReward);
        } else {
            task.status = TaskStatus.REJECTED;
            
            // 退还奖励给创建者
            payable(task.creator).transfer(task.reward);
            
            // 降低被分配者声誉
            _updateReputation(task.assignee, false);
        }
        
        emit TaskVerified(taskId, msg.sender, approved, block.timestamp);
    }
    
    /**
     * @dev 取消任务
     * @param taskId 任务ID
     */
    function cancelTask(uint256 taskId) 
        external 
        onlyTaskCreator(taskId)
        validTaskId(taskId)
        nonReentrant
    {
        Task storage task = tasks[taskId];
        require(
            task.status == TaskStatus.CREATED || task.status == TaskStatus.IN_PROGRESS,
            "TaskChain: Cannot cancel task in current status"
        );
        
        task.status = TaskStatus.CANCELLED;
        
        // 退还奖励
        payable(task.creator).transfer(task.reward);
        
        // 如果任务已分配，降低创建者声誉
        if (task.assignee != address(0)) {
            _updateReputation(task.creator, false);
        }
    }
    
    /**
     * @dev 更新用户声誉
     * @param user 用户地址
     * @param positive 是否为正面行为
     */
    function _updateReputation(address user, bool positive) internal {
        User storage userInfo = users[user];
        uint256 oldReputation = userInfo.reputation;
        
        if (positive) {
            userInfo.reputation += 10;
        } else {
            if (userInfo.reputation >= 20) {
                userInfo.reputation -= 20;
            } else {
                userInfo.reputation = 0;
            }
        }
        
        emit ReputationUpdated(user, oldReputation, userInfo.reputation);
    }
    
    /**
     * @dev 提取平台费用（仅管理员）
     * @param amount 提取金额
     */
    function withdrawPlatformFees(uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant 
    {
        require(amount <= platformBalance, "TaskChain: Insufficient platform balance");
        
        platformBalance -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    // ============================================================================
    // 查询函数
    // ============================================================================
    
    /**
     * @dev 获取任务详情
     * @param taskId 任务ID
     */
    function getTask(uint256 taskId) 
        external 
        view 
        validTaskId(taskId) 
        returns (Task memory) 
    {
        return tasks[taskId];
    }
    
    /**
     * @dev 获取用户信息
     * @param userAddress 用户地址
     */
    function getUser(address userAddress) 
        external 
        view 
        returns (User memory) 
    {
        return users[userAddress];
    }
    
    /**
     * @dev 获取用户创建的任务
     * @param userAddress 用户地址
     */
    function getUserTasks(address userAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userTasks[userAddress];
    }
    
    /**
     * @dev 获取用户被分配的任务
     * @param userAddress 用户地址
     */
    function getAssignedTasks(address userAddress) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return assignedTasks[userAddress];
    }
    
    /**
     * @dev 按标签获取任务
     * @param tag 标签
     */
    function getTasksByTag(string memory tag) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return tasksByTag[tag];
    }
    
    /**
     * @dev 获取公开任务列表
     * @param offset 偏移量
     * @param limit 限制数量
     */
    function getPublicTasks(uint256 offset, uint256 limit) 
        external 
        view 
        returns (uint256[] memory taskIds, uint256 total) 
    {
        uint256 totalTasks = _taskIdCounter.current();
        uint256[] memory publicTaskIds = new uint256[](totalTasks);
        uint256 publicCount = 0;
        
        // 收集所有公开任务
        for (uint256 i = 1; i <= totalTasks; i++) {
            if (tasks[i].isPublic && tasks[i].status == TaskStatus.CREATED) {
                publicTaskIds[publicCount] = i;
                publicCount++;
            }
        }
        
        // 应用分页
        uint256 start = offset;
        uint256 end = offset + limit;
        if (end > publicCount) {
            end = publicCount;
        }
        
        uint256[] memory result = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = publicTaskIds[i];
        }
        
        return (result, publicCount);
    }
    
    /**
     * @dev 检查用户是否申请了任务
     * @param taskId 任务ID
     * @param user 用户地址
     */
    function hasAppliedForTask(uint256 taskId, address user) 
        external 
        view 
        returns (bool) 
    {
        return taskApplications[taskId][user];
    }
    
    /**
     * @dev 获取当前任务ID计数器
     */
    function getCurrentTaskId() external view returns (uint256) {
        return _taskIdCounter.current();
    }
    
    /**
     * @dev 获取合约余额
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 获取平台余额
     */
    function getPlatformBalance() external view returns (uint256) {
        return platformBalance;
    }
    
    // ============================================================================
    // 管理员函数
    // ============================================================================
    
    /**
     * @dev 添加验证者角色
     * @param account 账户地址
     */
    function addVerifier(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(VERIFIER_ROLE, account);
    }
    
    /**
     * @dev 移除验证者角色
     * @param account 账户地址
     */
    function removeVerifier(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(VERIFIER_ROLE, account);
    }
    
    /**
     * @dev 添加管理员角色
     * @param account 账户地址
     */
    function addModerator(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MODERATOR_ROLE, account);
    }
    
    /**
     * @dev 紧急暂停任务（仅管理员）
     * @param taskId 任务ID
     */
    function emergencyPauseTask(uint256 taskId) 
        external 
        onlyRole(MODERATOR_ROLE) 
        validTaskId(taskId) 
    {
        Task storage task = tasks[taskId];
        require(
            task.status == TaskStatus.CREATED || task.status == TaskStatus.IN_PROGRESS,
            "TaskChain: Cannot pause task in current status"
        );
        
        task.status = TaskStatus.CANCELLED;
        
        // 退还奖励给创建者
        payable(task.creator).transfer(task.reward);
    }
    
    /**
     * @dev 批量验证任务（仅验证者）
     * @param taskIds 任务ID数组
     * @param approvals 批准状态数组
     */
    function batchVerifyTasks(uint256[] memory taskIds, bool[] memory approvals) 
        external 
        onlyRole(VERIFIER_ROLE) 
    {
        require(taskIds.length == approvals.length, "TaskChain: Arrays length mismatch");
        require(taskIds.length <= 10, "TaskChain: Too many tasks to verify at once");
        
        for (uint256 i = 0; i < taskIds.length; i++) {
            if (tasks[taskIds[i]].status == TaskStatus.COMPLETED) {
                verifyTask(taskIds[i], approvals[i]);
            }
        }
    }
    
    // ============================================================================
    // 接收以太币
    // ============================================================================
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {
        // 允许合约接收以太币
    }
    
    /**
     * @dev 回退函数
     */
    fallback() external payable {
        // 处理未知函数调用
    }
}

/**
 * @title TaskChainFactory
 * @dev 任务链工厂合约，用于部署多个TaskChain实例
 */
contract TaskChainFactory {
    address[] public deployedContracts;
    mapping(address => address[]) public userContracts;
    
    event TaskChainDeployed(address indexed deployer, address indexed contractAddress);
    
    /**
     * @dev 部署新的TaskChain合约
     */
    function deployTaskChain() external returns (address) {
        TaskChain newContract = new TaskChain();
        address contractAddress = address(newContract);
        
        deployedContracts.push(contractAddress);
        userContracts[msg.sender].push(contractAddress);
        
        emit TaskChainDeployed(msg.sender, contractAddress);
        
        return contractAddress;
    }
    
    /**
     * @dev 获取所有部署的合约
     */
    function getDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    /**
     * @dev 获取用户部署的合约
     */
    function getUserContracts(address user) external view returns (address[] memory) {
        return userContracts[user];
    }
    
    /**
     * @dev 获取部署的合约数量
     */
    function getContractCount() external view returns (uint256) {
        return deployedContracts.length;
    }
}