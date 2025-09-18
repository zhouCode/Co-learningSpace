// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SecureBasicToken - 安全加固版ERC20代币
 * @author 涂雨欣 (2023110835)
 * @notice 实现了多重安全机制的ERC20代币合约
 * @dev 集成访问控制、重入防护、暂停机制、黑名单等安全特性
 */
contract SecureBasicToken is ERC20, ERC20Pausable, AccessControl, ReentrancyGuard {
    using Address for address;
    
    // 角色定义
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");
    
    // 安全限制
    uint256 public constant MAX_SUPPLY = 1000000 * 10**18; // 最大供应量
    uint256 public constant MAX_TRANSFER_AMOUNT = 10000 * 10**18; // 单次转账限额
    uint256 public constant DAILY_TRANSFER_LIMIT = 50000 * 10**18; // 日转账限额
    
    // 状态变量
    mapping(address => bool) private _blacklisted;
    mapping(address => uint256) private _dailyTransferred;
    mapping(address => uint256) private _lastTransferDay;
    
    // 自定义错误
    error BlacklistedAddress(address account);
    error ExceedsMaxSupply(uint256 amount, uint256 maxSupply);
    error ExceedsTransferLimit(uint256 amount, uint256 limit);
    error ExceedsDailyLimit(uint256 amount, uint256 dailyLimit);
    error InvalidAddress(address account);
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferToSelf();
    
    // 事件定义
    event AddressBlacklisted(address indexed account, address indexed by);
    event AddressWhitelisted(address indexed account, address indexed by);
    event SecurityAlert(string alertType, address indexed account, uint256 amount);
    event DailyLimitExceeded(address indexed account, uint256 attempted, uint256 limit);
    
    // 修饰符
    modifier notBlacklisted(address account) {
        if (_blacklisted[account]) revert BlacklistedAddress(account);
        _;
    }
    
    modifier validAddress(address account) {
        if (account == address(0)) revert InvalidAddress(account);
        if (account.isContract() && account.code.length == 0) revert InvalidAddress(account);
        _;
    }
    
    modifier transferLimits(address from, uint256 amount) {
        if (amount > MAX_TRANSFER_AMOUNT) {
            revert ExceedsTransferLimit(amount, MAX_TRANSFER_AMOUNT);
        }
        
        uint256 currentDay = block.timestamp / 1 days;
        if (_lastTransferDay[from] != currentDay) {
            _dailyTransferred[from] = 0;
            _lastTransferDay[from] = currentDay;
        }
        
        if (_dailyTransferred[from] + amount > DAILY_TRANSFER_LIMIT) {
            emit DailyLimitExceeded(from, amount, DAILY_TRANSFER_LIMIT);
            revert ExceedsDailyLimit(amount, DAILY_TRANSFER_LIMIT);
        }
        
        _dailyTransferred[from] += amount;
        _;
    }
    
    /**
     * @dev 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        if (initialSupply > MAX_SUPPLY) {
            revert ExceedsMaxSupply(initialSupply, MAX_SUPPLY);
        }
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BLACKLIST_ROLE, msg.sender);
        
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @dev 安全转账函数
     */
    function transfer(address to, uint256 amount)
        public
        override
        nonReentrant
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        validAddress(to)
        transferLimits(msg.sender, amount)
        returns (bool)
    {
        if (to == msg.sender) revert TransferToSelf();
        
        uint256 senderBalance = balanceOf(msg.sender);
        if (senderBalance < amount) {
            revert InsufficientBalance(amount, senderBalance);
        }
        
        _transfer(msg.sender, to, amount);
        
        // 大额转账安全警报
        if (amount > MAX_TRANSFER_AMOUNT / 2) {
            emit SecurityAlert("LARGE_TRANSFER", msg.sender, amount);
        }
        
        return true;
    }
    
    /**
     * @dev 安全的授权转账
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        nonReentrant
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        notBlacklisted(msg.sender)
        validAddress(to)
        transferLimits(from, amount)
        returns (bool)
    {
        if (to == from) revert TransferToSelf();
        
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) {
            revert InsufficientBalance(amount, fromBalance);
        }
        
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        
        return true;
    }
    
    /**
     * @dev 铸造代币（仅MINTER_ROLE）
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        validAddress(to)
        notBlacklisted(to)
    {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply(amount, MAX_SUPPLY);
        }
        
        _mint(to, amount);
        emit SecurityAlert("MINT_OPERATION", to, amount);
    }
    
    /**
     * @dev 销毁代币（仅BURNER_ROLE）
     */
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
        emit SecurityAlert("BURN_OPERATION", msg.sender, amount);
    }
    
    /**
     * @dev 暂停合约（仅PAUSER_ROLE）
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复合约（仅PAUSER_ROLE）
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev 添加黑名单（仅BLACKLIST_ROLE）
     */
    function addToBlacklist(address account)
        external
        onlyRole(BLACKLIST_ROLE)
        validAddress(account)
    {
        _blacklisted[account] = true;
        emit AddressBlacklisted(account, msg.sender);
        emit SecurityAlert("BLACKLIST_ADDED", account, 0);
    }
    
    /**
     * @dev 移除黑名单（仅BLACKLIST_ROLE）
     */
    function removeFromBlacklist(address account)
        external
        onlyRole(BLACKLIST_ROLE)
    {
        _blacklisted[account] = false;
        emit AddressWhitelisted(account, msg.sender);
    }
    
    /**
     * @dev 检查地址是否在黑名单
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }
    
    /**
     * @dev 获取日转账额度
     */
    function getDailyTransferred(address account) external view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        if (_lastTransferDay[account] != currentDay) {
            return 0;
        }
        return _dailyTransferred[account];
    }
    
    /**
     * @dev 重写_beforeTokenTransfer以集成暂停功能
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}

/*
=== 涂雨欣的代币安全学习笔记 ===

ERC20代币安全设计的关键要素：

1. 【访问控制系统】
   - 使用OpenZeppelin的AccessControl实现基于角色的权限管理
   - 分离不同功能的权限：铸造、销毁、暂停、黑名单管理
   - 避免单点故障，支持多管理员模式

2. 【转账安全机制】
   - 重入攻击防护：使用ReentrancyGuard
   - 黑名单机制：防止恶意地址参与交易
   - 转账限额：单次和日累计限额防止大额异常转账
   - 地址验证：防止转账到无效地址

3. 【供应量控制】
   - 设置最大供应量上限
   - 铸造权限控制
   - 销毁机制实现通缩

4. 【紧急响应】
   - 暂停机制：紧急情况下停止所有转账
   - 黑名单功能：快速隔离恶意地址
   - 事件日志：完整的操作审计轨迹

5. 【错误处理】
   - 自定义错误：提供清晰的失败原因
   - 输入验证：所有外部输入都要验证
   - 边界检查：防止溢出和越界

6. 【监控和审计】
   - 安全事件日志：记录所有敏感操作
   - 大额转账警报：异常交易监控
   - 日限额跟踪：防止洗钱等非法活动

7. 【合规考虑】
   - KYC/AML支持：黑名单机制
   - 监管报告：详细的事件日志
   - 紧急冻结：暂停和黑名单功能

代币安全的核心理念：
"信任但验证" - 即使是授权用户也要进行必要的检查

常见代币攻击向量及防护：
- 重入攻击 → ReentrancyGuard + CEI模式
- 权限滥用 → 基于角色的访问控制
- 供应量操纵 → 最大供应量限制
- 恶意转账 → 黑名单 + 转账限额
- 合约暂停 → 多重签名 + 时间锁
*/