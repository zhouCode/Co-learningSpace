// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BasicToken - 高性能ERC20代币实现
 * @author 唐浚豪 (2023110554)
 * @notice 注重gas优化和性能的基础代币合约
 * @dev 通过位运算、批量操作和存储优化实现高效的代币系统
 * 学习日期: 2024年10月16日
 */
contract BasicToken {
    // 代币基本信息 - 使用常量节省gas
    string public constant name = "OptimizedToken";
    string public constant symbol = "OPT";
    uint8 public constant decimals = 18;
    
    // 总供应量和所有者信息打包存储
    uint256 public totalSupply;
    address public owner;
    
    // 余额映射
    mapping(address => uint256) private _balances;
    
    // 授权映射 - 嵌套映射用于allowance
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // 批量转账结构体，减少函数调用开销
    struct Transfer {
        address to;
        uint256 amount;
    }
    
    // 优化的事件定义
    event Transfer(indexed address from, indexed address to, uint256 value);
    event Approval(indexed address owner, indexed address spender, uint256 value);
    event BatchTransfer(indexed address from, uint256 totalAmount, uint256 recipientCount);
    
    // 自定义错误，节省gas
    error InsufficientBalance(uint256 requested, uint256 available);
    error InsufficientAllowance(uint256 requested, uint256 available);
    error InvalidAddress();
    error InvalidAmount();
    error NotOwner();
    error TransferFailed();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    
    /**
     * @dev 构造函数 - 优化初始化过程
     * @param _initialSupply 初始供应量
     */
    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        totalSupply = _initialSupply * 10**decimals;
        _balances[msg.sender] = totalSupply;
        
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    /**
     * @dev 获取账户余额
     * @param account 账户地址
     * @return 账户余额
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev 转账函数 - 内联优化
     * @param to 接收地址
     * @param amount 转账金额
     * @return 转账是否成功
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }
    
    /**
     * @dev 批量转账 - 性能优化的核心功能
     * @param transfers 转账信息数组
     * @return 是否全部成功
     */
    function batchTransfer(Transfer[] calldata transfers) external returns (bool) {
        uint256 totalAmount = 0;
        uint256 senderBalance = _balances[msg.sender];
        
        // 第一轮：计算总金额并验证
        for (uint256 i = 0; i < transfers.length;) {
            if (transfers[i].to == address(0)) revert InvalidAddress();
            if (transfers[i].amount == 0) revert InvalidAmount();
            
            totalAmount += transfers[i].amount;
            
            unchecked {
                ++i;
            }
        }
        
        // 检查余额是否足够
        if (senderBalance < totalAmount) {
            revert InsufficientBalance(totalAmount, senderBalance);
        }
        
        // 第二轮：执行转账
        _balances[msg.sender] = senderBalance - totalAmount;
        
        for (uint256 i = 0; i < transfers.length;) {
            _balances[transfers[i].to] += transfers[i].amount;
            emit Transfer(msg.sender, transfers[i].to, transfers[i].amount);
            
            unchecked {
                ++i;
            }
        }
        
        emit BatchTransfer(msg.sender, totalAmount, transfers.length);
        return true;
    }
    
    /**
     * @dev 授权函数
     * @param spender 被授权地址
     * @param amount 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev 查询授权额度
     * @param tokenOwner 代币所有者
     * @param spender 被授权者
     * @return 授权额度
     */
    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }
    
    /**
     * @dev 代理转账
     * @param from 发送方
     * @param to 接收方
     * @param amount 金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        
        if (currentAllowance < amount) {
            revert InsufficientAllowance(amount, currentAllowance);
        }
        
        // 使用unchecked优化，因为已经检查过余额
        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        
        return _transfer(from, to, amount);
    }
    
    /**
     * @dev 内部转账函数 - 核心逻辑优化
     * @param from 发送方
     * @param to 接收方
     * @param amount 金额
     * @return 是否成功
     */
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(amount, fromBalance);
        }
        
        // 使用unchecked优化算术运算
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev 铸造代币 - 仅所有者
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        
        totalSupply += amount;
        _balances[to] += amount;
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external {
        uint256 balance = _balances[msg.sender];
        if (balance < amount) {
            revert InsufficientBalance(amount, balance);
        }
        
        unchecked {
            _balances[msg.sender] = balance - amount;
            totalSupply -= amount;
        }
        
        emit Transfer(msg.sender, address(0), amount);
    }
    
    /**
     * @dev 增加授权额度 - 避免竞态条件
     * @param spender 被授权地址
     * @param addedValue 增加的额度
     * @return 是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        
        uint256 newAllowance = _allowances[msg.sender][spender] + addedValue;
        _allowances[msg.sender][spender] = newAllowance;
        
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }
    
    /**
     * @dev 减少授权额度
     * @param spender 被授权地址
     * @param subtractedValue 减少的额度
     * @return 是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert InsufficientAllowance(subtractedValue, currentAllowance);
        }
        
        unchecked {
            uint256 newAllowance = currentAllowance - subtractedValue;
            _allowances[msg.sender][spender] = newAllowance;
            emit Approval(msg.sender, spender, newAllowance);
        }
        
        return true;
    }
}

/**
 * 个人学习笔记 - 唐浚豪
 * 
 * 代币合约性能优化策略：
 * 1. 批量操作：实现batchTransfer减少多次交易的gas消耗
 * 2. 算术优化：使用unchecked块避免不必要的溢出检查
 * 3. 存储优化：合理使用mapping和减少存储写入次数
 * 4. 事件优化：设计高效的事件结构便于链下查询
 * 5. 错误处理：自定义错误替代字符串，节省部署和执行成本
 * 
 * 关键性能考虑：
 * - ERC20标准的完整实现，同时注重gas效率
 * - 批量转账功能可以显著降低大量转账的总gas消耗
 * - 使用内联函数和unchecked算术运算提高执行效率
 * - 合理的数据结构设计减少存储槽位占用
 * 
 * 学习收获：
 * - 理解了ERC20标准的核心机制和安全考虑
 * - 掌握了Solidity中的性能优化技巧
 * - 学会了如何在保证功能完整性的同时优化gas消耗
 */