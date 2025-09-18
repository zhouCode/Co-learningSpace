// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BasicToken - 基于ERC20理论的代币实现
 * @author 朱海涛 (2023110571)
 * @notice 深入理解代币经济学和ERC20标准的理论基础实现
 * @dev 基于数学证明和形式化验证思想的安全代币合约
 * 学习日期: 2024年10月16日
 */

/**
 * @dev ERC20标准接口定义
 * 基于EIP-20提案，定义了代币合约的标准接口
 * 这种标准化设计体现了区块链生态的互操作性原则
 */
interface IERC20 {
    /// @notice 返回代币总供应量
    /// @return 总供应量数值
    function totalSupply() external view returns (uint256);
    
    /// @notice 返回指定账户的代币余额
    /// @param account 查询的账户地址
    /// @return 账户余额
    function balanceOf(address account) external view returns (uint256);
    
    /// @notice 转移代币到指定地址
    /// @param to 接收方地址
    /// @param amount 转移数量
    /// @return 操作是否成功
    function transfer(address to, uint256 amount) external returns (bool);
    
    /// @notice 查询授权额度
    /// @param owner 代币所有者
    /// @param spender 被授权者
    /// @return 授权额度
    function allowance(address owner, address spender) external view returns (uint256);
    
    /// @notice 授权第三方使用代币
    /// @param spender 被授权者地址
    /// @param amount 授权数量
    /// @return 操作是否成功
    function approve(address spender, uint256 amount) external returns (bool);
    
    /// @notice 第三方转移代币
    /// @param from 发送方地址
    /// @param to 接收方地址
    /// @param amount 转移数量
    /// @return 操作是否成功
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    /// @notice 转移事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /// @notice 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev ERC20元数据扩展接口
 * 提供代币的描述性信息，增强用户体验
 */
interface IERC20Metadata is IERC20 {
    /// @notice 代币名称
    function name() external view returns (string memory);
    
    /// @notice 代币符号
    function symbol() external view returns (string memory);
    
    /// @notice 代币精度
    function decimals() external view returns (uint8);
}

/**
 * @title 数学安全库
 * @dev 基于数学证明的安全算术运算
 * 防止整数溢出和下溢，确保数值计算的正确性
 */
library SafeMath {
    /**
     * @dev 安全加法
     * @param a 被加数
     * @param b 加数
     * @return 和
     * @notice 基于数学恒等式：a + b >= a 当且仅当 b >= 0
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    /**
     * @dev 安全减法
     * @param a 被减数
     * @param b 减数
     * @return 差
     * @notice 基于数学恒等式：a - b <= a 当且仅当 b >= 0
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    
    /**
     * @dev 安全减法（带错误信息）
     * @param a 被减数
     * @param b 减数
     * @param errorMessage 错误信息
     * @return 差
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    
    /**
     * @dev 安全乘法
     * @param a 被乘数
     * @param b 乘数
     * @return 积
     * @notice 基于数学原理：如果a != 0，则a * b / a == b
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    
    /**
     * @dev 安全除法
     * @param a 被除数
     * @param b 除数
     * @return 商
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

/**
 * @title BasicToken - ERC20代币的理论化实现
 * @dev 基于形式化验证思想和数学证明的代币合约
 * 每个函数都包含完整的前置条件、后置条件和不变量检查
 */
contract BasicToken is IERC20, IERC20Metadata {
    using SafeMath for uint256;
    
    // 状态变量 - 合约的核心数据结构
    mapping(address => uint256) private _balances;           // 余额映射
    mapping(address => mapping(address => uint256)) private _allowances; // 授权映射
    
    uint256 private _totalSupply;    // 总供应量
    string private _name;            // 代币名称
    string private _symbol;          // 代币符号
    uint8 private _decimals;         // 代币精度
    
    // 合约所有者
    address private _owner;
    
    // 铸造和销毁事件
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // 自定义错误
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    
    /**
     * @dev 修饰符：仅所有者可调用
     * 基于访问控制理论，实现权限分离
     */
    modifier onlyOwner() {
        if (_owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }
    
    /**
     * @dev 构造函数
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param decimals_ 代币精度
     * @param initialSupply 初始供应量
     * @notice 初始化代币的基本属性和初始分配
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply
    ) {
        // 输入验证 - 防御性编程原则
        require(bytes(name_).length > 0, "Token name cannot be empty");
        require(bytes(symbol_).length > 0, "Token symbol cannot be empty");
        require(decimals_ <= 18, "Decimals cannot exceed 18");
        
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _owner = msg.sender;
        
        // 初始供应量分配给部署者
        if (initialSupply > 0) {
            _totalSupply = initialSupply;
            _balances[msg.sender] = initialSupply;
            emit Transfer(address(0), msg.sender, initialSupply);
        }
        
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    /**
     * @dev 实现IERC20Metadata接口
     * @return 代币名称
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    
    /**
     * @dev 实现IERC20Metadata接口
     * @return 代币符号
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    
    /**
     * @dev 实现IERC20Metadata接口
     * @return 代币精度
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev 实现IERC20接口 - 总供应量查询
     * @return 当前总供应量
     * @notice 不变量：totalSupply == sum(balances[i]) for all i
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev 实现IERC20接口 - 余额查询
     * @param account 查询账户
     * @return 账户余额
     * @notice 前置条件：account != address(0)
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev 实现IERC20接口 - 代币转移
     * @param to 接收方地址
     * @param amount 转移数量
     * @return 操作成功标志
     * @notice 前置条件：to != address(0) && balanceOf(msg.sender) >= amount
     * @notice 后置条件：balanceOf(to) == old(balanceOf(to)) + amount
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }
    
    /**
     * @dev 实现IERC20接口 - 授权查询
     * @param owner 代币所有者
     * @param spender 被授权者
     * @return 授权数量
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev 实现IERC20接口 - 授权操作
     * @param spender 被授权者地址
     * @param amount 授权数量
     * @return 操作成功标志
     * @notice 前置条件：spender != address(0)
     * @notice 后置条件：allowance(msg.sender, spender) == amount
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }
    
    /**
     * @dev 实现IERC20接口 - 授权转移
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转移数量
     * @return 操作成功标志
     * @notice 前置条件：allowance(from, msg.sender) >= amount
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev 增加授权额度
     * @param spender 被授权者
     * @param addedValue 增加的额度
     * @return 操作成功标志
     * @notice 解决ERC20的竞态条件问题
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender).add(addedValue));
        return true;
    }
    
    /**
     * @dev 减少授权额度
     * @param spender 被授权者
     * @param subtractedValue 减少的额度
     * @return 操作成功标志
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(owner, spender, currentAllowance.sub(subtractedValue));
        return true;
    }
    
    /**
     * @dev 铸造新代币 - 仅所有者
     * @param to 接收方地址
     * @param amount 铸造数量
     * @notice 前置条件：to != address(0)
     * @notice 后置条件：totalSupply == old(totalSupply) + amount
     */
    function mint(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     * @notice 前置条件：balanceOf(msg.sender) >= amount
     * @notice 后置条件：totalSupply == old(totalSupply) - amount
     */
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 转移所有权
     * @param newOwner 新所有者地址
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
    
    /**
     * @dev 获取所有者地址
     * @return 当前所有者地址
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    /**
     * @dev 内部转移函数 - 核心转移逻辑
     * @param from 发送方
     * @param to 接收方
     * @param amount 转移数量
     * @notice 实现原子性转移，确保状态一致性
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }
        
        // 状态更新 - 确保原子性
        _balances[from] = fromBalance.sub(amount);
        _balances[to] = _balances[to].add(amount);
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 内部铸造函数
     * @param to 接收方
     * @param amount 铸造数量
     */
    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        
        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @dev 内部销毁函数
     * @param from 销毁方
     * @param amount 销毁数量
     */
    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }
        
        _balances[from] = fromBalance.sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        
        emit Transfer(from, address(0), amount);
        emit Burn(from, amount);
    }
    
    /**
     * @dev 内部授权函数
     * @param owner 所有者
     * @param spender 被授权者
     * @param amount 授权数量
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /**
     * @dev 消费授权额度
     * @param owner 所有者
     * @param spender 消费者
     * @param amount 消费数量
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            }
            _approve(owner, spender, currentAllowance.sub(amount));
        }
    }
    
    /**
     * @dev 内部所有权转移
     * @param newOwner 新所有者
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * 个人学习笔记 - 朱海涛
 * 
 * ERC20标准的理论基础分析：
 * 1. 代币经济学原理：代币作为价值载体的数学模型
 * 2. 状态机理论：每次转移都是状态转换，需要保证一致性
 * 3. 不变量理论：totalSupply = Σbalances[i] 必须始终成立
 * 4. 原子性原理：转移操作要么完全成功，要么完全失败
 * 
 * 形式化验证思想的应用：
 * - 前置条件(Precondition)：函数执行前必须满足的条件
 * - 后置条件(Postcondition)：函数执行后保证的结果
 * - 不变量(Invariant)：在整个合约生命周期中保持不变的性质
 * - 终止性(Termination)：所有函数都能在有限步骤内完成
 * 
 * 数学安全性保证：
 * - 使用SafeMath库防止整数溢出
 * - 零地址检查防止代币丢失
 * - 余额检查确保转移的有效性
 * - 授权机制实现安全的第三方操作
 * 
 * 设计模式的理论基础：
 * - 访问控制模式：基于角色的权限管理
 * - 状态模式：合约状态的管理和转换
 * - 观察者模式：通过事件实现状态变化的通知
 * - 工厂模式：标准化的代币创建流程
 * 
 * 学习心得：
 * - 理解了代币标准背后的经济学和数学原理
 * - 掌握了形式化验证在智能合约中的应用
 * - 学会了如何设计安全可靠的代币系统
 * - 认识到标准化对区块链生态的重要意义
 */