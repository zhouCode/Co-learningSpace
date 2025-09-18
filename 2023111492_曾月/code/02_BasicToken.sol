// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BasicToken - 优雅简洁的代币合约
 * @dev 体现优雅编程风格和简洁设计理念的ERC20代币实现
 * @author 曾月 (2023111492)
 * 
 * 设计特色：
 * 1. 优雅的架构：清晰的接口分离、简洁的继承结构
 * 2. 简洁的实现：最小化代码复杂度、专注核心功能
 * 3. 美学导向：代码布局如诗、命名如画、逻辑如歌
 * 4. 禅意设计：删繁就简、返璞归真、大道至简
 */

// ============================================================================
// 优雅的接口设计
// ============================================================================

/**
 * @dev 简洁优雅的ERC20接口
 */
interface IERC20Elegant {
    // 核心查询功能
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    
    // 核心转账功能
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    // 优雅的事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev 优雅的元数据接口
 */
interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @dev 优雅的扩展功能接口
 */
interface IElegantExtensions {
    // 优雅的铸造和销毁
    function mint(address to, uint256 amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);
    function burnFrom(address from, uint256 amount) external returns (bool);
    
    // 优雅的暂停功能
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    
    // 优雅的事件
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event PauseStateChanged(bool paused);
}

// ============================================================================
// 优雅的工具库
// ============================================================================

/**
 * @dev 优雅的数学运算库
 */
library ElegantMath {
    /**
     * @dev 优雅的安全加法
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }
    
    /**
     * @dev 优雅的安全减法
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction underflow");
        return a - b;
    }
    
    /**
     * @dev 优雅的安全乘法
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "Multiplication overflow");
        return c;
    }
    
    /**
     * @dev 优雅的安全除法
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }
}

/**
 * @dev 优雅的地址工具库
 */
library ElegantAddress {
    /**
     * @dev 检查地址是否为零地址
     */
    function isZero(address addr) internal pure returns (bool) {
        return addr == address(0);
    }
    
    /**
     * @dev 确保地址非零
     */
    function requireNonZero(address addr, string memory message) internal pure {
        require(!isZero(addr), message);
    }
    
    /**
     * @dev 优雅的地址验证
     */
    function validate(address addr) internal pure returns (bool) {
        return !isZero(addr);
    }
}

// ============================================================================
// 优雅的访问控制
// ============================================================================

/**
 * @dev 简洁优雅的所有权管理
 */
abstract contract ElegantOwnable {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    modifier onlyOwner() {
        require(owner() == msg.sender, "Caller is not the owner");
        _;
    }
    
    function owner() public view returns (address) {
        return _owner;
    }
    
    function renounceOwnership() public onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        ElegantAddress.requireNonZero(newOwner, "New owner cannot be zero address");
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev 优雅的暂停功能
 */
abstract contract ElegantPausable {
    bool private _paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    constructor() {
        _paused = false;
    }
    
    modifier whenNotPaused() {
        require(!paused(), "Contract is paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused(), "Contract is not paused");
        _;
    }
    
    function paused() public view returns (bool) {
        return _paused;
    }
    
    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

// ============================================================================
// 主合约：优雅的代币实现
// ============================================================================

contract BasicToken is 
    IERC20Elegant, 
    IERC20Metadata, 
    IElegantExtensions, 
    ElegantOwnable, 
    ElegantPausable 
{
    using ElegantMath for uint256;
    using ElegantAddress for address;
    
    // ========================================================================
    // 优雅的状态变量
    // ========================================================================
    
    /// @dev 代币的诗意名称
    string private constant _NAME = "Elegant Token";
    
    /// @dev 代币的简洁符号
    string private constant _SYMBOL = "ELEGANT";
    
    /// @dev 代币的精度，体现数学之美
    uint8 private constant _DECIMALS = 18;
    
    /// @dev 总供应量，有限而珍贵
    uint256 private _totalSupply;
    
    /// @dev 最大供应量，设定边界之美
    uint256 private constant _MAX_SUPPLY = 1000000 * 10**_DECIMALS; // 100万代币
    
    /// @dev 账户余额映射，记录每个地址的财富
    mapping(address => uint256) private _balances;
    
    /// @dev 授权映射，体现信任的艺术
    mapping(address => mapping(address => uint256)) private _allowances;
    
    /// @dev 铸造者权限，创造的力量
    mapping(address => bool) private _minters;
    
    /// @dev 黑名单，保护生态的纯净
    mapping(address => bool) private _blacklisted;
    
    // ========================================================================
    // 优雅的修饰符
    // ========================================================================
    
    /// @dev 确保地址有效
    modifier validAddress(address addr) {
        addr.requireNonZero("Invalid address: zero address");
        _;
    }
    
    /// @dev 确保金额有效
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Invalid amount: must be positive");
        _;
    }
    
    /// @dev 确保用户未被列入黑名单
    modifier notBlacklisted(address addr) {
        require(!_blacklisted[addr], "Address is blacklisted");
        _;
    }
    
    /// @dev 确保调用者是铸造者
    modifier onlyMinter() {
        require(_minters[msg.sender] || msg.sender == owner(), "Caller is not a minter");
        _;
    }
    
    /// @dev 确保不超过最大供应量
    modifier withinMaxSupply(uint256 amount) {
        require(_totalSupply.add(amount) <= _MAX_SUPPLY, "Exceeds maximum supply");
        _;
    }
    
    // ========================================================================
    // 构造函数：优雅的诞生
    // ========================================================================
    
    constructor(uint256 initialSupply) {
        require(initialSupply <= _MAX_SUPPLY, "Initial supply exceeds maximum");
        
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
        _minters[msg.sender] = true;
        
        emit Transfer(address(0), msg.sender, initialSupply);
    }
    
    // ========================================================================
    // ERC20 元数据功能
    // ========================================================================
    
    function name() public pure override returns (string memory) {
        return _NAME;
    }
    
    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }
    
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }
    
    // ========================================================================
    // ERC20 核心功能
    // ========================================================================
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function transfer(
        address to, 
        uint256 amount
    ) public override whenNotPaused notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(
        address spender, 
        uint256 amount
    ) public override whenNotPaused notBlacklisted(msg.sender) returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override whenNotPaused notBlacklisted(from) notBlacklisted(to) returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance.sub(amount));
        
        return true;
    }
    
    // ========================================================================
    // 优雅的扩展功能
    // ========================================================================
    
    /**
     * @dev 优雅的铸造功能
     */
    function mint(
        address to, 
        uint256 amount
    ) public override onlyMinter validAddress(to) validAmount(amount) withinMaxSupply(amount) whenNotPaused returns (bool) {
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        
        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
        
        return true;
    }
    
    /**
     * @dev 优雅的销毁功能
     */
    function burn(
        uint256 amount
    ) public override validAmount(amount) whenNotPaused returns (bool) {
        require(_balances[msg.sender] >= amount, "Burn amount exceeds balance");
        
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        
        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
        
        return true;
    }
    
    /**
     * @dev 优雅的代理销毁功能
     */
    function burnFrom(
        address from, 
        uint256 amount
    ) public override validAddress(from) validAmount(amount) whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Burn amount exceeds allowance");
        require(_balances[from] >= amount, "Burn amount exceeds balance");
        
        _balances[from] = _balances[from].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        _approve(from, msg.sender, currentAllowance.sub(amount));
        
        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
        
        return true;
    }
    
    // ========================================================================
    // 暂停功能
    // ========================================================================
    
    function pause() public override onlyOwner {
        _pause();
        emit PauseStateChanged(true);
    }
    
    function unpause() public override onlyOwner {
        _unpause();
        emit PauseStateChanged(false);
    }
    
    // ========================================================================
    // 管理功能
    // ========================================================================
    
    /**
     * @dev 添加铸造者
     */
    function addMinter(address minter) public onlyOwner validAddress(minter) {
        _minters[minter] = true;
    }
    
    /**
     * @dev 移除铸造者
     */
    function removeMinter(address minter) public onlyOwner {
        _minters[minter] = false;
    }
    
    /**
     * @dev 检查是否为铸造者
     */
    function isMinter(address account) public view returns (bool) {
        return _minters[account];
    }
    
    /**
     * @dev 添加到黑名单
     */
    function addToBlacklist(address account) public onlyOwner validAddress(account) {
        _blacklisted[account] = true;
    }
    
    /**
     * @dev 从黑名单移除
     */
    function removeFromBlacklist(address account) public onlyOwner {
        _blacklisted[account] = false;
    }
    
    /**
     * @dev 检查是否在黑名单
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }
    
    // ========================================================================
    // 优雅的便利功能
    // ========================================================================
    
    /**
     * @dev 增加授权额度
     */
    function increaseAllowance(
        address spender, 
        uint256 addedValue
    ) public whenNotPaused returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }
    
    /**
     * @dev 减少授权额度
     */
    function decreaseAllowance(
        address spender, 
        uint256 subtractedValue
    ) public whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
        
        _approve(msg.sender, spender, currentAllowance.sub(subtractedValue));
        return true;
    }
    
    /**
     * @dev 批量转账
     */
    function batchTransfer(
        address[] memory recipients, 
        uint256[] memory amounts
    ) public whenNotPaused returns (bool) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i].validate(), "Invalid recipient address");
            require(!_blacklisted[recipients[i]], "Recipient is blacklisted");
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        
        return true;
    }
    
    // ========================================================================
    // 查询功能
    // ========================================================================
    
    /**
     * @dev 获取最大供应量
     */
    function maxSupply() public pure returns (uint256) {
        return _MAX_SUPPLY;
    }
    
    /**
     * @dev 获取剩余可铸造数量
     */
    function remainingMintable() public view returns (uint256) {
        return _MAX_SUPPLY.sub(_totalSupply);
    }
    
    /**
     * @dev 获取合约信息
     */
    function getContractInfo() public view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 currentSupply,
        uint256 maximumSupply,
        bool isPaused
    ) {
        return (
            _NAME,
            _SYMBOL,
            _DECIMALS,
            _totalSupply,
            _MAX_SUPPLY,
            paused()
        );
    }
    
    // ========================================================================
    // 内部辅助函数
    // ========================================================================
    
    /**
     * @dev 内部转账函数
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal validAddress(from) validAddress(to) validAmount(amount) {
        require(_balances[from] >= amount, "Transfer amount exceeds balance");
        
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount);
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 内部授权函数
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal validAddress(owner) validAddress(spender) {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

/**
 * 设计特色总结：
 * 
 * 1. 优雅的架构设计：
 *    - 清晰的接口分离和模块化设计
 *    - 简洁的继承结构和组合模式
 *    - 优美的抽象层次和职责划分
 *    - 和谐的功能组织和代码布局
 * 
 * 2. 简洁的实现方式：
 *    - 最小化代码复杂度和冗余
 *    - 专注核心功能的纯粹实现
 *    - 优雅的错误处理和边界检查
 *    - 简洁而完整的功能覆盖
 * 
 * 3. 美学导向的编程：
 *    - 代码布局如诗般优美
 *    - 函数命名如画般生动
 *    - 逻辑流程如歌般流畅
 *    - 注释风格如文般雅致
 * 
 * 4. 禅意设计哲学：
 *    - 删繁就简的功能设计
 *    - 返璞归真的实现方式
 *    - 大道至简的架构理念
 *    - 静中有动的交互体验
 * 
 * 这个代币合约展现了对编程艺术的深刻理解，
 * 将技术实现与美学追求完美结合，
 * 体现了优雅简洁的设计哲学。
 */