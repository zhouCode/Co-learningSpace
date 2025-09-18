// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BasicToken - 实用主义的代币合约
 * @author 唐秋平 (2023110659)
 * @notice 注重实际应用和用户体验的ERC20代币实现
 * @dev 以解决实际业务需求为导向的代币设计
 * 学习日期: 2024年10月16日
 */

/**
 * @dev ERC20标准接口 - 实用主义：只实现必要的接口
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title BasicToken - 实用主义代币合约
 * @dev 专注于实际应用场景的代币实现
 * 特点：
 * 1. 简单易用的接口
 * 2. 实用的管理功能
 * 3. 用户友好的特性
 * 4. 实际业务场景考虑
 */
contract BasicToken is IERC20 {
    // ============ 基础状态变量 ============
    
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalSupply;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ============ 实用功能状态变量 ============
    
    address public owner;
    bool public isPaused;
    
    // 实用功能：交易费用
    uint256 public transferFeeRate; // 基点 (1 = 0.01%)
    address public feeCollector;
    bool public feeEnabled;
    
    // 实用功能：黑名单管理
    mapping(address => bool) public blacklisted;
    
    // 实用功能：批量转账限制
    uint256 public maxBatchSize = 100;
    
    // 实用功能：转账限制
    uint256 public maxTransferAmount;
    uint256 public dailyTransferLimit;
    mapping(address => uint256) public dailyTransferred;
    mapping(address => uint256) public lastTransferDay;
    
    // 实用功能：VIP用户（免费转账）
    mapping(address => bool) public vipUsers;
    
    // ============ 事件定义 ============
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);
    event FeeCollected(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event VIPStatusUpdated(address indexed account, bool isVIP);
    event TransferLimitUpdated(uint256 maxAmount, uint256 dailyLimit);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    
    // 实用功能：批量操作事件
    event BatchTransfer(address indexed from, uint256 totalAmount, uint256 recipientCount);
    event BatchMint(address indexed to, uint256 totalAmount, uint256 recipientCount);
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier whenNotPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }
    
    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Account is blacklisted");
        _;
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数 - 实用主义：提供灵活的初始化选项
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _decimals 代币精度
     * @param _initialSupply 初始供应量
     * @param _feeRate 转账费率（基点）
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        uint256 _feeRate
    ) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");
        require(_decimals <= 18, "Decimals too high");
        require(_feeRate <= 1000, "Fee rate too high (max 10%)"); // 实用限制
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        
        // 实用设置：合理的默认值
        transferFeeRate = _feeRate;
        feeCollector = msg.sender;
        feeEnabled = _feeRate > 0;
        
        // 实用设置：转账限制（防止大额误操作）
        maxTransferAmount = _initialSupply / 10; // 最大单次转账为总供应量的10%
        dailyTransferLimit = _initialSupply / 20; // 日限额为总供应量的5%
        
        // 铸造初始供应量
        if (_initialSupply > 0) {
            _totalSupply = _initialSupply;
            _balances[msg.sender] = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
        
        // 设置部署者为VIP用户
        vipUsers[msg.sender] = true;
        emit VIPStatusUpdated(msg.sender, true);
    }
    
    // ============ ERC20标准实现 ============
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev 转账函数 - 实用主义：集成多种实用功能
     * @param to 接收方地址
     * @param amount 转账金额
     * @return 操作是否成功
     */
    function transfer(address to, uint256 amount) public override whenNotPaused notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        _transferWithFee(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev 授权函数 - 实用主义：添加安全检查
     * @param spender 被授权方地址
     * @param amount 授权金额
     * @return 操作是否成功
     */
    function approve(address spender, uint256 amount) public override whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender) returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev 授权转账函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账金额
     * @return 操作是否成功
     */
    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused notBlacklisted(from) notBlacklisted(to) returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        
        _transferWithFee(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        
        return true;
    }
    
    // ============ 实用功能函数 ============
    
    /**
     * @dev 批量转账 - 实用功能：提高效率
     * @param recipients 接收方地址数组
     * @param amounts 转账金额数组
     */
    function batchTransfer(address[] memory recipients, uint256[] memory amounts) public whenNotPaused notBlacklisted(msg.sender) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= maxBatchSize, "Batch size too large");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(_balances[msg.sender] >= totalAmount, "Insufficient balance for batch transfer");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!blacklisted[recipients[i]], "Recipient is blacklisted");
            _transferWithFee(msg.sender, recipients[i], amounts[i]);
        }
        
        emit BatchTransfer(msg.sender, totalAmount, recipients.length);
    }
    
    /**
     * @dev 等额批量转账 - 实用功能：简化操作
     * @param recipients 接收方地址数组
     * @param amount 每人转账金额
     */
    function batchTransferEqual(address[] memory recipients, uint256 amount) public whenNotPaused notBlacklisted(msg.sender) {
        require(recipients.length <= maxBatchSize, "Batch size too large");
        
        uint256 totalAmount = amount * recipients.length;
        require(_balances[msg.sender] >= totalAmount, "Insufficient balance for batch transfer");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!blacklisted[recipients[i]], "Recipient is blacklisted");
            _transferWithFee(msg.sender, recipients[i], amount);
        }
        
        emit BatchTransfer(msg.sender, totalAmount, recipients.length);
    }
    
    /**
     * @dev 增加授权额度 - 实用功能：避免重复授权
     * @param spender 被授权方
     * @param addedValue 增加的额度
     * @return 操作是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    
    /**
     * @dev 减少授权额度
     * @param spender 被授权方
     * @param subtractedValue 减少的额度
     * @return 操作是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }
    
    /**
     * @dev 获取用户今日剩余转账额度 - 实用功能：用户查询
     * @param user 用户地址
     * @return 剩余额度
     */
    function getRemainingDailyLimit(address user) public view returns (uint256) {
        uint256 today = block.timestamp / 86400; // 当前日期
        if (lastTransferDay[user] != today) {
            return dailyTransferLimit;
        }
        if (dailyTransferred[user] >= dailyTransferLimit) {
            return 0;
        }
        return dailyTransferLimit - dailyTransferred[user];
    }
    
    /**
     * @dev 检查转账是否可行 - 实用工具：预检查
     * @param from 发送方
     * @param to 接收方
     * @param amount 转账金额
     * @return canTransfer 是否可以转账
     * @return reason 不能转账的原因
     */
    function canTransfer(address from, address to, uint256 amount) public view returns (bool canTransfer, string memory reason) {
        if (isPaused) return (false, "Contract is paused");
        if (blacklisted[from]) return (false, "Sender is blacklisted");
        if (blacklisted[to]) return (false, "Recipient is blacklisted");
        if (_balances[from] < amount) return (false, "Insufficient balance");
        if (amount > maxTransferAmount && !vipUsers[from]) return (false, "Amount exceeds maximum transfer limit");
        
        // 检查日限额
        if (!vipUsers[from]) {
            uint256 remaining = getRemainingDailyLimit(from);
            if (amount > remaining) return (false, "Amount exceeds daily transfer limit");
        }
        
        return (true, "Transfer is allowed");
    }
    
    // ============ 管理功能 ============
    
    /**
     * @dev 铸造代币 - 实用功能：供应量管理
     * @param to 接收方地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) public onlyOwner validAddress(to) {
        require(!blacklisted[to], "Cannot mint to blacklisted address");
        
        _totalSupply += amount;
        _balances[to] += amount;
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev 批量铸造 - 实用功能：批量分发
     * @param recipients 接收方数组
     * @param amounts 铸造数量数组
     */
    function batchMint(address[] memory recipients, uint256[] memory amounts) public onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= maxBatchSize, "Batch size too large");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            require(!blacklisted[recipients[i]], "Cannot mint to blacklisted address");
            
            _balances[recipients[i]] += amounts[i];
            totalAmount += amounts[i];
            
            emit Transfer(address(0), recipients[i], amounts[i]);
        }
        
        _totalSupply += totalAmount;
        emit BatchMint(address(0), totalAmount, recipients.length);
    }
    
    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) public {
        require(_balances[msg.sender] >= amount, "Burn amount exceeds balance");
        
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        
        emit Transfer(msg.sender, address(0), amount);
    }
    
    /**
     * @dev 设置黑名单 - 实用功能：风险控制
     * @param account 账户地址
     * @param isBlacklisted 是否加入黑名单
     */
    function setBlacklist(address account, bool isBlacklisted) public onlyOwner validAddress(account) {
        require(account != owner, "Cannot blacklist owner");
        blacklisted[account] = isBlacklisted;
        emit BlacklistUpdated(account, isBlacklisted);
    }
    
    /**
     * @dev 批量设置黑名单
     * @param accounts 账户地址数组
     * @param isBlacklisted 是否加入黑名单
     */
    function batchSetBlacklist(address[] memory accounts, bool isBlacklisted) public onlyOwner {
        require(accounts.length <= maxBatchSize, "Batch size too large");
        
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && accounts[i] != owner) {
                blacklisted[accounts[i]] = isBlacklisted;
                emit BlacklistUpdated(accounts[i], isBlacklisted);
            }
        }
    }
    
    /**
     * @dev 设置VIP用户 - 实用功能：特权管理
     * @param account 账户地址
     * @param isVIP 是否为VIP
     */
    function setVIPStatus(address account, bool isVIP) public onlyOwner validAddress(account) {
        vipUsers[account] = isVIP;
        emit VIPStatusUpdated(account, isVIP);
    }
    
    /**
     * @dev 设置费率 - 实用功能：费用管理
     * @param newRate 新费率（基点）
     */
    function setFeeRate(uint256 newRate) public onlyOwner {
        require(newRate <= 1000, "Fee rate too high (max 10%)");
        uint256 oldRate = transferFeeRate;
        transferFeeRate = newRate;
        feeEnabled = newRate > 0;
        emit FeeRateUpdated(oldRate, newRate);
    }
    
    /**
     * @dev 设置费用收集者
     * @param newCollector 新的费用收集者地址
     */
    function setFeeCollector(address newCollector) public onlyOwner validAddress(newCollector) {
        feeCollector = newCollector;
    }
    
    /**
     * @dev 设置转账限制 - 实用功能：风险控制
     * @param maxAmount 最大单次转账金额
     * @param dailyLimit 日转账限额
     */
    function setTransferLimits(uint256 maxAmount, uint256 dailyLimit) public onlyOwner {
        require(maxAmount > 0 && dailyLimit > 0, "Limits must be positive");
        require(maxAmount <= _totalSupply, "Max amount exceeds total supply");
        require(dailyLimit <= _totalSupply, "Daily limit exceeds total supply");
        
        maxTransferAmount = maxAmount;
        dailyTransferLimit = dailyLimit;
        
        emit TransferLimitUpdated(maxAmount, dailyLimit);
    }
    
    /**
     * @dev 暂停/恢复合约
     * @param pause 是否暂停
     */
    function setPaused(bool pause) public onlyOwner {
        isPaused = pause;
        if (pause) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }
    
    /**
     * @dev 转移所有权
     * @param newOwner 新所有者地址
     */
    function transferOwnership(address newOwner) public onlyOwner validAddress(newOwner) {
        require(newOwner != owner, "New owner must be different");
        require(!blacklisted[newOwner], "New owner cannot be blacklisted");
        
        address oldOwner = owner;
        owner = newOwner;
        
        // 新所有者自动成为VIP
        vipUsers[newOwner] = true;
        emit VIPStatusUpdated(newOwner, true);
        
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 带费用的转账函数
     * @param from 发送方
     * @param to 接收方
     * @param amount 转账金额
     */
    function _transferWithFee(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Transfer amount exceeds balance");
        
        // 检查转账限制（VIP用户免检）
        if (!vipUsers[from]) {
            require(amount <= maxTransferAmount, "Amount exceeds maximum transfer limit");
            
            // 检查日限额
            uint256 today = block.timestamp / 86400;
            if (lastTransferDay[from] != today) {
                dailyTransferred[from] = 0;
                lastTransferDay[from] = today;
            }
            require(dailyTransferred[from] + amount <= dailyTransferLimit, "Amount exceeds daily transfer limit");
            dailyTransferred[from] += amount;
        }
        
        uint256 fee = 0;
        uint256 transferAmount = amount;
        
        // 计算费用（VIP用户免费）
        if (feeEnabled && !vipUsers[from] && from != owner) {
            fee = (amount * transferFeeRate) / 10000;
            transferAmount = amount - fee;
        }
        
        // 执行转账
        _balances[from] -= amount;
        _balances[to] += transferAmount;
        
        // 收取费用
        if (fee > 0) {
            _balances[feeCollector] += fee;
            emit Transfer(from, feeCollector, fee);
            emit FeeCollected(from, to, amount, fee);
        }
        
        emit Transfer(from, to, transferAmount);
    }
    
    /**
     * @dev 内部授权函数
     * @param owner 所有者
     * @param spender 被授权者
     * @param amount 授权金额
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // ============ 应急功能 ============
    
    /**
     * @dev 应急提取以太币
     */
    function emergencyWithdrawETH() public onlyOwner {
        require(address(this).balance > 0, "No ETH to withdraw");
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev 应急提取其他代币
     * @param token 代币合约地址
     * @param amount 提取数量
     */
    function emergencyWithdrawToken(address token, uint256 amount) public onlyOwner {
        require(token != address(this), "Cannot withdraw own token");
        IERC20(token).transfer(owner, amount);
    }
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {
        // 实用考虑：允许接收以太币用于支付gas费用
    }
}

/**
 * 个人学习笔记 - 唐秋平
 * 
 * 实用主义代币设计的核心要素：
 * 1. 用户体验优先：批量操作、预检查功能、清晰的错误信息
 * 2. 业务需求导向：费用机制、VIP系统、转账限制
 * 3. 风险控制实用：黑名单、暂停功能、日限额
 * 4. 管理便利性：批量管理、应急功能、灵活配置
 * 
 * 实际应用场景考虑：
 * - 费用机制：为项目方提供收入来源
 * - VIP系统：激励大户和重要用户
 * - 转账限制：防止大额误操作和恶意攻击
 * - 批量操作：提高空投和分发效率
 * - 黑名单：应对监管和风险控制需求
 * 
 * 实用功能的设计思路：
 * - 预检查功能：让用户在操作前了解是否会成功
 * - 批量操作：减少gas费用和操作复杂度
 * - 灵活配置：适应不同的业务需求变化
 * - 应急机制：应对突发情况和意外事件
 * 
 * 用户友好性体现：
 * - 清晰的错误提示
 * - 剩余额度查询
 * - 操作可行性检查
 * - 合理的默认参数
 * 
 * 实用主义vs完美主义的权衡：
 * - 不追求理论上的完美，关注实际使用效果
 * - 在功能丰富性和合约复杂度之间找平衡
 * - 优先实现高频使用的功能
 * - 保持代码的可读性和可维护性
 * 
 * 学习心得：
 * - 理解了实际项目中代币合约的常见需求
 * - 学会了从业务角度思考技术实现
 * - 掌握了用户体验设计在智能合约中的应用
 * - 认识到实用功能对项目成功的重要性
 * - 体会到了简单实用比复杂完美更有价值
 */