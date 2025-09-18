// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 模块化架构代币系统
 * @dev 展示清晰模块分离和可扩展设计的ERC20实现
 * @author 杜俊哲 (2023111182)
 * @notice 使用模块化设计模式构建的代币合约
 */

// ============================================================================
// 核心接口模块
// ============================================================================

/**
 * @dev ERC20标准接口
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
 * @dev 访问控制接口
 */
interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
}

/**
 * @dev 暂停功能接口
 */
interface IPausable {
    function paused() external view returns (bool);
    function pause() external;
    function unpause() external;
    
    event Paused(address account);
    event Unpaused(address account);
}

/**
 * @dev 铸造销毁接口
 */
interface IMintBurn {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
}

/**
 * @dev 批量操作接口
 */
interface IBatchOperations {
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external returns (bool);
    function batchApprove(address[] calldata spenders, uint256[] calldata amounts) external returns (bool);
    function batchTransferFrom(address[] calldata froms, address[] calldata tos, uint256[] calldata amounts) external returns (bool);
}

// ============================================================================
// 抽象基础模块
// ============================================================================

/**
 * @dev 上下文抽象合约
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev 访问控制抽象合约
 */
abstract contract AccessControl is Context, IAccessControl {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    
    mapping(bytes32 => RoleData) private _roles;
    
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }
    
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }
    
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert("AccessControl: account missing role");
        }
    }
    
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");
        _revokeRole(role, account);
    }
    
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }
    
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
    }
    
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }
    
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

/**
 * @dev 暂停功能抽象合约
 */
abstract contract Pausable is Context, IPausable {
    bool private _paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    constructor() {
        _paused = false;
    }
    
    function paused() public view virtual override returns (bool) {
        return _paused;
    }
    
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// ============================================================================
// 核心存储模块
// ============================================================================

/**
 * @dev 代币存储模块
 */
contract TokenStorage {
    // 基础代币信息
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    
    // 余额和授权映射
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    
    // 扩展存储
    mapping(address => bool) internal _frozenAccounts;
    mapping(address => uint256) internal _lockUntil;
    mapping(address => uint256) internal _dailyLimit;
    mapping(address => mapping(uint256 => uint256)) internal _dailySpent;
    
    // 历史记录存储
    struct TransferRecord {
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        bytes32 txHash;
    }
    
    TransferRecord[] internal _transferHistory;
    mapping(address => uint256[]) internal _userTransferIndices;
    
    // 统计数据存储
    struct Statistics {
        uint256 totalTransfers;
        uint256 totalVolume;
        uint256 uniqueHolders;
        uint256 lastUpdateTime;
    }
    
    Statistics internal _stats;
    
    // 配置参数存储
    struct Config {
        uint256 maxSupply;
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 transferFeeRate;
        bool transferFeeEnabled;
        address feeRecipient;
    }
    
    Config internal _config;
}

// ============================================================================
// 业务逻辑模块
// ============================================================================

/**
 * @dev 转账逻辑模块
 */
contract TransferLogic is TokenStorage {
    
    event TransferWithFee(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event DailyLimitSet(address indexed account, uint256 limit);
    
    modifier notFrozen(address account) {
        require(!_frozenAccounts[account], "TransferLogic: account is frozen");
        _;
    }
    
    modifier notLocked(address account) {
        require(block.timestamp >= _lockUntil[account], "TransferLogic: account is locked");
        _;
    }
    
    modifier withinDailyLimit(address account, uint256 amount) {
        uint256 today = block.timestamp / 1 days;
        uint256 dailySpent = _dailySpent[account][today];
        uint256 limit = _dailyLimit[account];
        
        if (limit > 0) {
            require(dailySpent + amount <= limit, "TransferLogic: daily limit exceeded");
        }
        _;
    }
    
    function _transfer(address from, address to, uint256 amount) internal 
        notFrozen(from) 
        notFrozen(to) 
        notLocked(from) 
        withinDailyLimit(from, amount) 
    {
        require(from != address(0), "TransferLogic: transfer from zero address");
        require(to != address(0), "TransferLogic: transfer to zero address");
        require(amount >= _config.minTransferAmount, "TransferLogic: amount below minimum");
        require(amount <= _config.maxTransferAmount, "TransferLogic: amount above maximum");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "TransferLogic: insufficient balance");
        
        // 计算手续费
        uint256 fee = 0;
        if (_config.transferFeeEnabled && _config.transferFeeRate > 0) {
            fee = (amount * _config.transferFeeRate) / 10000;
            require(fromBalance >= amount + fee, "TransferLogic: insufficient balance for fee");
        }
        
        // 执行转账
        _balances[from] = fromBalance - amount - fee;
        _balances[to] += amount;
        
        // 处理手续费
        if (fee > 0 && _config.feeRecipient != address(0)) {
            _balances[_config.feeRecipient] += fee;
            emit TransferWithFee(from, to, amount, fee);
        }
        
        // 更新每日支出
        uint256 today = block.timestamp / 1 days;
        _dailySpent[from][today] += amount + fee;
        
        // 记录转账历史
        _recordTransfer(from, to, amount);
        
        // 更新统计数据
        _updateStatistics(amount);
        
        emit IERC20.Transfer(from, to, amount);
        if (fee > 0) {
            emit IERC20.Transfer(from, _config.feeRecipient, fee);
        }
    }
    
    function _recordTransfer(address from, address to, uint256 amount) internal {
        TransferRecord memory record = TransferRecord({
            from: from,
            to: to,
            amount: amount,
            timestamp: block.timestamp,
            txHash: keccak256(abi.encodePacked(from, to, amount, block.timestamp))
        });
        
        uint256 index = _transferHistory.length;
        _transferHistory.push(record);
        
        _userTransferIndices[from].push(index);
        _userTransferIndices[to].push(index);
    }
    
    function _updateStatistics(uint256 amount) internal {
        _stats.totalTransfers++;
        _stats.totalVolume += amount;
        _stats.lastUpdateTime = block.timestamp;
    }
    
    function freezeAccount(address account) external {
        _frozenAccounts[account] = true;
        emit AccountFrozen(account);
    }
    
    function unfreezeAccount(address account) external {
        _frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }
    
    function setDailyLimit(address account, uint256 limit) external {
        _dailyLimit[account] = limit;
        emit DailyLimitSet(account, limit);
    }
    
    function lockAccount(address account, uint256 unlockTime) external {
        require(unlockTime > block.timestamp, "TransferLogic: unlock time must be in future");
        _lockUntil[account] = unlockTime;
    }
}

/**
 * @dev 铸造销毁逻辑模块
 */
contract MintBurnLogic is TokenStorage {
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "MintBurnLogic: mint to zero address");
        require(_totalSupply + amount <= _config.maxSupply, "MintBurnLogic: exceeds max supply");
        
        _totalSupply += amount;
        _balances[to] += amount;
        
        // 更新持有者统计
        if (_balances[to] == amount) {
            _stats.uniqueHolders++;
        }
        
        emit Mint(to, amount);
        emit IERC20.Transfer(address(0), to, amount);
    }
    
    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "MintBurnLogic: burn from zero address");
        
        uint256 accountBalance = _balances[from];
        require(accountBalance >= amount, "MintBurnLogic: burn amount exceeds balance");
        
        _balances[from] = accountBalance - amount;
        _totalSupply -= amount;
        
        // 更新持有者统计
        if (_balances[from] == 0) {
            _stats.uniqueHolders--;
        }
        
        emit Burn(from, amount);
        emit IERC20.Transfer(from, address(0), amount);
    }
}

/**
 * @dev 批量操作逻辑模块
 */
contract BatchOperationsLogic is TransferLogic {
    
    function _batchTransfer(address[] memory recipients, uint256[] memory amounts) internal returns (bool) {
        require(recipients.length == amounts.length, "BatchOperationsLogic: arrays length mismatch");
        require(recipients.length <= 100, "BatchOperationsLogic: too many recipients");
        
        address sender = _msgSender();
        uint256 totalAmount = 0;
        
        // 预计算总金额
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(_balances[sender] >= totalAmount, "BatchOperationsLogic: insufficient total balance");
        
        // 执行批量转账
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(sender, recipients[i], amounts[i]);
        }
        
        return true;
    }
    
    function _batchApprove(address[] memory spenders, uint256[] memory amounts) internal returns (bool) {
        require(spenders.length == amounts.length, "BatchOperationsLogic: arrays length mismatch");
        require(spenders.length <= 100, "BatchOperationsLogic: too many spenders");
        
        address owner = _msgSender();
        
        for (uint256 i = 0; i < spenders.length; i++) {
            _approve(owner, spenders[i], amounts[i]);
        }
        
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BatchOperationsLogic: approve from zero address");
        require(spender != address(0), "BatchOperationsLogic: approve to zero address");
        
        _allowances[owner][spender] = amount;
        emit IERC20.Approval(owner, spender, amount);
    }
}

// ============================================================================
// 查询服务模块
// ============================================================================

/**
 * @dev 查询服务模块
 */
contract QueryService is TokenStorage {
    
    function getTransferHistory(address account, uint256 offset, uint256 limit) 
        external 
        view 
        returns (TransferRecord[] memory) 
    {
        uint256[] memory indices = _userTransferIndices[account];
        require(offset < indices.length, "QueryService: offset out of bounds");
        
        uint256 end = offset + limit;
        if (end > indices.length) {
            end = indices.length;
        }
        
        TransferRecord[] memory records = new TransferRecord[](end - offset);
        
        for (uint256 i = offset; i < end; i++) {
            records[i - offset] = _transferHistory[indices[i]];
        }
        
        return records;
    }
    
    function getAccountInfo(address account) 
        external 
        view 
        returns (
            uint256 balance,
            bool isFrozen,
            uint256 lockUntil,
            uint256 dailyLimit,
            uint256 dailySpent
        ) 
    {
        uint256 today = block.timestamp / 1 days;
        
        return (
            _balances[account],
            _frozenAccounts[account],
            _lockUntil[account],
            _dailyLimit[account],
            _dailySpent[account][today]
        );
    }
    
    function getStatistics() 
        external 
        view 
        returns (Statistics memory) 
    {
        return _stats;
    }
    
    function getConfig() 
        external 
        view 
        returns (Config memory) 
    {
        return _config;
    }
    
    function getTopHolders(uint256 limit) 
        external 
        view 
        returns (address[] memory holders, uint256[] memory balances) 
    {
        // 简化实现，实际需要排序算法
        holders = new address[](limit);
        balances = new uint256[](limit);
        
        // 这里需要实现排序逻辑
        return (holders, balances);
    }
}

// ============================================================================
// 主合约模块管理器
// ============================================================================

/**
 * @dev 模块化代币主合约
 */
contract ModularToken is 
    IERC20, 
    IMintBurn, 
    IBatchOperations,
    AccessControl, 
    Pausable, 
    TransferLogic, 
    MintBurnLogic, 
    BatchOperationsLogic, 
    QueryService 
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 maxSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        
        // 初始化配置
        _config = Config({
            maxSupply: maxSupply_,
            minTransferAmount: 1,
            maxTransferAmount: maxSupply_,
            transferFeeRate: 0,
            transferFeeEnabled: false,
            feeRecipient: address(0)
        });
        
        // 初始化统计
        _stats = Statistics({
            totalTransfers: 0,
            totalVolume: 0,
            uniqueHolders: 1,
            lastUpdateTime: block.timestamp
        });
        
        // 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(BURNER_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        
        // 铸造初始供应量
        if (totalSupply_ > 0) {
            _mint(_msgSender(), totalSupply_);
        }
    }
    
    // ============================================================================
    // ERC20标准实现
    // ============================================================================
    
    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[from][_msgSender()];
        require(currentAllowance >= amount, "ModularToken: insufficient allowance");
        
        _transfer(from, to, amount);
        _approve(from, _msgSender(), currentAllowance - amount);
        
        return true;
    }
    
    // ============================================================================
    // 铸造销毁功能
    // ============================================================================
    
    function mint(address to, uint256 amount) public override onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) public override whenNotPaused {
        _burn(_msgSender(), amount);
    }
    
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) whenNotPaused {
        uint256 currentAllowance = _allowances[account][_msgSender()];
        require(currentAllowance >= amount, "ModularToken: burn amount exceeds allowance");
        
        _burn(account, amount);
        _approve(account, _msgSender(), currentAllowance - amount);
    }
    
    // ============================================================================
    // 批量操作功能
    // ============================================================================
    
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) 
        external 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return _batchTransfer(recipients, amounts);
    }
    
    function batchApprove(address[] calldata spenders, uint256[] calldata amounts) 
        external 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return _batchApprove(spenders, amounts);
    }
    
    function batchTransferFrom(address[] calldata froms, address[] calldata tos, uint256[] calldata amounts) 
        external 
        override 
        whenNotPaused 
        returns (bool) 
    {
        require(froms.length == tos.length && tos.length == amounts.length, "ModularToken: arrays length mismatch");
        
        for (uint256 i = 0; i < froms.length; i++) {
            transferFrom(froms[i], tos[i], amounts[i]);
        }
        
        return true;
    }
    
    // ============================================================================
    // 管理功能
    // ============================================================================
    
    function pause() public override onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() public override onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function setConfig(
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 transferFeeRate,
        bool transferFeeEnabled,
        address feeRecipient
    ) external onlyRole(ADMIN_ROLE) {
        _config.minTransferAmount = minTransferAmount;
        _config.maxTransferAmount = maxTransferAmount;
        _config.transferFeeRate = transferFeeRate;
        _config.transferFeeEnabled = transferFeeEnabled;
        _config.feeRecipient = feeRecipient;
    }
    
    // ============================================================================
    // 模块状态查询
    // ============================================================================
    
    function getModuleInfo() external pure returns (
        string memory architecture,
        string[] memory modules,
        string memory version
    ) {
        modules = new string[](8);
        modules[0] = "AccessControl";
        modules[1] = "Pausable";
        modules[2] = "TransferLogic";
        modules[3] = "MintBurnLogic";
        modules[4] = "BatchOperationsLogic";
        modules[5] = "QueryService";
        modules[6] = "TokenStorage";
        modules[7] = "ModularToken";
        
        return (
            "Modular Architecture",
            modules,
            "1.0.0"
        );
    }
}

/*
模块化架构代币特色：

1. 接口分离原则
   - 清晰的接口定义
   - 功能职责分离
   - 可扩展设计
   - 标准化实现

2. 抽象基础模块
   - Context上下文管理
   - AccessControl权限控制
   - Pausable暂停机制
   - 可重用组件设计

3. 存储模块分离
   - TokenStorage数据存储
   - 结构化数据管理
   - 配置参数分离
   - 历史记录管理

4. 业务逻辑模块
   - TransferLogic转账逻辑
   - MintBurnLogic铸造销毁
   - BatchOperationsLogic批量操作
   - 单一职责原则

5. 查询服务模块
   - QueryService查询接口
   - 数据聚合服务
   - 统计信息提供
   - 只读操作分离

6. 主合约管理器
   - ModularToken主控制器
   - 模块组合管理
   - 统一接口暴露
   - 版本控制支持

这种设计体现了模块化架构的核心优势：
可维护性、可扩展性、可测试性、代码复用。
*/