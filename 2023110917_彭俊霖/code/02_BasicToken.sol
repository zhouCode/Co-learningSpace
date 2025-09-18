// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 安全导向代币合约
 * @dev 注重安全性的ERC20代币实现
 * @author 彭俊霖 (2023110917)
 * @notice 展示多层安全防护机制
 */

contract SecureToken {
    // 安全状态变量
    string public constant name = "Secure Token";
    string public constant symbol = "SECURE";
    uint8 public constant decimals = 18;
    uint256 private _totalSupply;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // 安全控制变量
    address private _owner;
    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _whitelist;
    mapping(address => uint256) private _lastTransactionTime;
    mapping(address => uint256) private _dailyTransferAmount;
    mapping(address => uint256) private _dailyTransferCount;
    
    bool private _paused = false;
    bool private _emergencyStop = false;
    uint256 private _maxTransferAmount;
    uint256 private _dailyTransferLimit;
    uint256 private _maxDailyTransactions;
    uint256 private _transferCooldown;
    
    // 安全事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event SecurityAlert(string alertType, address indexed account, uint256 amount);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event EmergencyStop(bool stopped);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // 安全修饰符
    modifier onlyOwner() {
        require(msg.sender == _owner, "SECURE: caller is not the owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!_paused, "SECURE: token transfer while paused");
        _;
    }
    
    modifier whenNotEmergencyStopped() {
        require(!_emergencyStop, "SECURE: emergency stop activated");
        _;
    }
    
    modifier notBlacklisted(address account) {
        require(!_blacklist[account], "SECURE: account is blacklisted");
        _;
    }
    
    modifier validAddress(address account) {
        require(account != address(0), "SECURE: invalid address");
        require(account != address(this), "SECURE: cannot transfer to contract");
        _;
    }
    
    modifier transferLimits(address from, uint256 amount) {
        if (!_whitelist[from]) {
            require(amount <= _maxTransferAmount, "SECURE: transfer amount exceeds limit");
            require(
                _dailyTransferAmount[from] + amount <= _dailyTransferLimit,
                "SECURE: daily transfer limit exceeded"
            );
            require(
                _dailyTransferCount[from] < _maxDailyTransactions,
                "SECURE: daily transaction count exceeded"
            );
            require(
                block.timestamp >= _lastTransactionTime[from] + _transferCooldown,
                "SECURE: transfer cooldown not met"
            );
        }
        _;
    }
    
    constructor(uint256 initialSupply) {
        _owner = msg.sender;
        _totalSupply = initialSupply * 10**decimals;
        _balances[msg.sender] = _totalSupply;
        
        // 初始化安全参数
        _maxTransferAmount = _totalSupply / 100; // 1% of total supply
        _dailyTransferLimit = _totalSupply / 50; // 2% of total supply per day
        _maxDailyTransactions = 10;
        _transferCooldown = 60; // 1 minute cooldown
        
        // 将owner加入白名单
        _whitelist[msg.sender] = true;
        
        emit Transfer(address(0), msg.sender, _totalSupply);
        emit WhitelistUpdated(msg.sender, true);
    }
    
    /**
     * @dev 安全的余额查询
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev 安全的总供应量查询
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev 安全的授权查询
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev 安全转账功能
     */
    function transfer(address to, uint256 amount) 
        public 
        whenNotPaused 
        whenNotEmergencyStopped
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        validAddress(to)
        transferLimits(msg.sender, amount)
        returns (bool) 
    {
        _secureTransfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev 安全授权转账
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        whenNotPaused 
        whenNotEmergencyStopped
        notBlacklisted(from)
        notBlacklisted(to)
        notBlacklisted(msg.sender)
        validAddress(to)
        transferLimits(from, amount)
        returns (bool) 
    {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "SECURE: transfer amount exceeds allowance");
        
        _secureTransfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    /**
     * @dev 安全授权
     */
    function approve(address spender, uint256 amount) 
        public 
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        validAddress(spender)
        returns (bool) 
    {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev 内部安全转账实现
     */
    function _secureTransfer(address from, address to, uint256 amount) private {
        require(_balances[from] >= amount, "SECURE: transfer amount exceeds balance");
        
        // 检查重入攻击
        require(_lastTransactionTime[from] != block.timestamp, "SECURE: reentrancy detected");
        
        // 更新余额
        _balances[from] -= amount;
        _balances[to] += amount;
        
        // 更新安全统计
        _updateTransferStats(from, amount);
        
        // 检查异常转账模式
        _checkSuspiciousActivity(from, to, amount);
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 更新转账统计
     */
    function _updateTransferStats(address account, uint256 amount) private {
        uint256 today = block.timestamp / 1 days;
        uint256 lastTransactionDay = _lastTransactionTime[account] / 1 days;
        
        // 如果是新的一天，重置统计
        if (today > lastTransactionDay) {
            _dailyTransferAmount[account] = 0;
            _dailyTransferCount[account] = 0;
        }
        
        _dailyTransferAmount[account] += amount;
        _dailyTransferCount[account]++;
        _lastTransactionTime[account] = block.timestamp;
    }
    
    /**
     * @dev 检查可疑活动
     */
    function _checkSuspiciousActivity(address from, address to, uint256 amount) private {
        // 检查大额转账
        if (amount > _totalSupply / 20) { // 5% of total supply
            emit SecurityAlert("Large Transfer", from, amount);
        }
        
        // 检查频繁转账
        if (_dailyTransferCount[from] > _maxDailyTransactions / 2) {
            emit SecurityAlert("Frequent Transfers", from, _dailyTransferCount[from]);
        }
        
        // 检查快速连续转账
        if (block.timestamp - _lastTransactionTime[from] < 30) {
            emit SecurityAlert("Rapid Transfers", from, amount);
        }
    }
    
    /**
     * @dev 内部授权实现
     */
    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /**
     * @dev 增加授权额度
     */
    function increaseAllowance(address spender, uint256 addedValue) 
        public 
        validAddress(spender)
        returns (bool) 
    {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    
    /**
     * @dev 减少授权额度
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        public 
        validAddress(spender)
        returns (bool) 
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "SECURE: decreased allowance below zero");
        
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }
    
    /**
     * @dev 黑名单管理
     */
    function addToBlacklist(address account) public onlyOwner validAddress(account) {
        _blacklist[account] = true;
        emit BlacklistUpdated(account, true);
        emit SecurityAlert("Account Blacklisted", account, 0);
    }
    
    function removeFromBlacklist(address account) public onlyOwner {
        _blacklist[account] = false;
        emit BlacklistUpdated(account, false);
    }
    
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }
    
    /**
     * @dev 白名单管理
     */
    function addToWhitelist(address account) public onlyOwner validAddress(account) {
        _whitelist[account] = true;
        emit WhitelistUpdated(account, true);
    }
    
    function removeFromWhitelist(address account) public onlyOwner {
        _whitelist[account] = false;
        emit WhitelistUpdated(account, false);
    }
    
    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist[account];
    }
    
    /**
     * @dev 暂停/恢复功能
     */
    function pause() public onlyOwner {
        _paused = true;
        emit SecurityAlert("Contract Paused", msg.sender, 0);
    }
    
    function unpause() public onlyOwner {
        _paused = false;
        emit SecurityAlert("Contract Unpaused", msg.sender, 0);
    }
    
    function isPaused() public view returns (bool) {
        return _paused;
    }
    
    /**
     * @dev 紧急停止功能
     */
    function emergencyStop() public onlyOwner {
        _emergencyStop = true;
        emit EmergencyStop(true);
        emit SecurityAlert("Emergency Stop Activated", msg.sender, 0);
    }
    
    function emergencyResume() public onlyOwner {
        _emergencyStop = false;
        emit EmergencyStop(false);
        emit SecurityAlert("Emergency Stop Deactivated", msg.sender, 0);
    }
    
    function isEmergencyStopped() public view returns (bool) {
        return _emergencyStop;
    }
    
    /**
     * @dev 安全参数设置
     */
    function setMaxTransferAmount(uint256 amount) public onlyOwner {
        require(amount > 0 && amount <= _totalSupply, "SECURE: invalid max transfer amount");
        _maxTransferAmount = amount;
    }
    
    function setDailyTransferLimit(uint256 limit) public onlyOwner {
        require(limit > 0 && limit <= _totalSupply, "SECURE: invalid daily limit");
        _dailyTransferLimit = limit;
    }
    
    function setMaxDailyTransactions(uint256 count) public onlyOwner {
        require(count > 0, "SECURE: invalid transaction count");
        _maxDailyTransactions = count;
    }
    
    function setTransferCooldown(uint256 cooldown) public onlyOwner {
        require(cooldown <= 3600, "SECURE: cooldown too long"); // Max 1 hour
        _transferCooldown = cooldown;
    }
    
    /**
     * @dev 获取安全参数
     */
    function getSecurityParams() public view returns (
        uint256 maxTransferAmount,
        uint256 dailyTransferLimit,
        uint256 maxDailyTransactions,
        uint256 transferCooldown
    ) {
        return (_maxTransferAmount, _dailyTransferLimit, _maxDailyTransactions, _transferCooldown);
    }
    
    /**
     * @dev 获取账户安全统计
     */
    function getAccountStats(address account) public view returns (
        uint256 dailyTransferAmount,
        uint256 dailyTransferCount,
        uint256 lastTransactionTime,
        bool isBlacklisted_,
        bool isWhitelisted_
    ) {
        return (
            _dailyTransferAmount[account],
            _dailyTransferCount[account],
            _lastTransactionTime[account],
            _blacklist[account],
            _whitelist[account]
        );
    }
    
    /**
     * @dev 所有权转移
     */
    function transferOwnership(address newOwner) public onlyOwner validAddress(newOwner) {
        require(newOwner != _owner, "SECURE: new owner is the same as current owner");
        
        address previousOwner = _owner;
        _owner = newOwner;
        
        // 更新白名单
        _whitelist[previousOwner] = false;
        _whitelist[newOwner] = true;
        
        emit OwnershipTransferred(previousOwner, newOwner);
        emit WhitelistUpdated(previousOwner, false);
        emit WhitelistUpdated(newOwner, true);
    }
    
    function owner() public view returns (address) {
        return _owner;
    }
}

/*
安全导向代币设计特色：

1. 多层安全防护
   - 黑白名单机制
   - 转账限额控制
   - 冷却时间限制
   - 紧急停止功能

2. 异常检测
   - 大额转账监控
   - 频繁交易检测
   - 重入攻击防护
   - 可疑活动报警

3. 访问控制
   - 严格的权限管理
   - 地址有效性验证
   - 状态检查修饰符
   - 安全事件记录

4. 风险管理
   - 每日转账限制
   - 交易频率控制
   - 暂停恢复机制
   - 参数动态调整

5. 审计友好
   - 详细的安全事件
   - 完整的状态追踪
   - 清晰的错误信息
   - 透明的安全参数

这种设计体现了安全第一的理念：
多重防护、异常检测、风险控制、审计透明。
*/