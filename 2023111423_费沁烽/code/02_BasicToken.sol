// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 函数式编程风格代币合约
 * @dev 采用函数式编程理念的ERC20代币实现
 * @author 费沁烽 (2023111423)
 */

contract FunctionalToken {
    // 不可变代币信息
    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
    }
    
    // 账户状态 - 函数式数据结构
    struct Account {
        uint256 balance;
        mapping(address => uint256) allowances;
        bool isActive;
        uint256 lastTransactionTime;
    }
    
    // 交易记录 - 不可变历史
    struct Transaction {
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        bytes32 txHash;
    }
    
    TokenInfo private immutable tokenInfo;
    mapping(address => Account) private accounts;
    Transaction[] private transactionHistory;
    address private immutable owner;
    
    // 函数式事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AccountActivated(address indexed account);
    event TransactionRecorded(bytes32 indexed txHash, address from, address to, uint256 amount);
    
    // 函数式修饰符 - 高阶函数概念
    modifier pure_validation(
        function(address, uint256) pure returns (bool) validator,
        address addr,
        uint256 amount
    ) {
        require(validator(addr, amount), "Pure validation failed");
        _;
    }
    
    modifier compose_transfer_checks(
        address from,
        address to,
        uint256 amount
    ) {
        require(
            isValidAddress(to) && 
            hasEnoughBalance(from, amount) && 
            isValidAmount(amount),
            "Transfer validation failed"
        );
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        tokenInfo = TokenInfo({
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            totalSupply: _initialSupply * 10**_decimals
        });
        
        owner = msg.sender;
        accounts[msg.sender].balance = tokenInfo.totalSupply;
        accounts[msg.sender].isActive = true;
        accounts[msg.sender].lastTransactionTime = block.timestamp;
        
        emit Transfer(address(0), msg.sender, tokenInfo.totalSupply);
        _recordTransaction(address(0), msg.sender, tokenInfo.totalSupply);
    }
    
    // 纯函数 - 验证函数
    function isValidAddress(address _addr) public pure returns (bool) {
        return _addr != address(0);
    }
    
    function isValidAmount(uint256 _amount) public pure returns (bool) {
        return _amount > 0;
    }
    
    function hasEnoughBalance(address _account, uint256 _amount) public view returns (bool) {
        return accounts[_account].balance >= _amount;
    }
    
    function isValidTransfer(address _to, uint256 _amount) public pure returns (bool) {
        return _to != address(0) && _amount > 0;
    }
    
    // 纯函数 - 数学运算
    function safeAdd(uint256 _a, uint256 _b) public pure returns (uint256) {
        uint256 result = _a + _b;
        require(result >= _a, "Addition overflow");
        return result;
    }
    
    function safeSub(uint256 _a, uint256 _b) public pure returns (uint256) {
        require(_b <= _a, "Subtraction underflow");
        return _a - _b;
    }
    
    function calculatePercentage(uint256 _amount, uint256 _percentage) public pure returns (uint256) {
        require(_percentage <= 100, "Invalid percentage");
        return (_amount * _percentage) / 100;
    }
    
    // 函数式查询 - 不可变视图
    function name() public view returns (string memory) {
        return tokenInfo.name;
    }
    
    function symbol() public view returns (string memory) {
        return tokenInfo.symbol;
    }
    
    function decimals() public view returns (uint8) {
        return tokenInfo.decimals;
    }
    
    function totalSupply() public view returns (uint256) {
        return tokenInfo.totalSupply;
    }
    
    function balanceOf(address _account) public view returns (uint256) {
        return accounts[_account].balance;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return accounts[_owner].allowances[_spender];
    }
    
    // 函数式转账 - 不可变操作
    function transfer(address _to, uint256 _amount) 
        public 
        pure_validation(isValidTransfer, _to, _amount)
        compose_transfer_checks(msg.sender, _to, _amount)
        returns (bool) 
    {
        return _executeTransfer(msg.sender, _to, _amount);
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) 
        public 
        compose_transfer_checks(_from, _to, _amount)
        returns (bool) 
    {
        require(
            accounts[_from].allowances[msg.sender] >= _amount,
            "Insufficient allowance"
        );
        
        accounts[_from].allowances[msg.sender] = safeSub(
            accounts[_from].allowances[msg.sender],
            _amount
        );
        
        return _executeTransfer(_from, _to, _amount);
    }
    
    // 内部函数式转账实现
    function _executeTransfer(address _from, address _to, uint256 _amount) 
        private 
        returns (bool) 
    {
        // 创建新的账户状态而非直接修改
        accounts[_from].balance = safeSub(accounts[_from].balance, _amount);
        accounts[_to].balance = safeAdd(accounts[_to].balance, _amount);
        
        // 更新时间戳
        accounts[_from].lastTransactionTime = block.timestamp;
        accounts[_to].lastTransactionTime = block.timestamp;
        
        // 激活接收账户
        if (!accounts[_to].isActive) {
            accounts[_to].isActive = true;
            emit AccountActivated(_to);
        }
        
        // 记录不可变交易历史
        _recordTransaction(_from, _to, _amount);
        
        emit Transfer(_from, _to, _amount);
        return true;
    }
    
    // 函数式授权
    function approve(address _spender, uint256 _amount) 
        public 
        pure_validation(isValidTransfer, _spender, _amount)
        returns (bool) 
    {
        accounts[msg.sender].allowances[_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
    
    // 函数式授权增加
    function increaseAllowance(address _spender, uint256 _addedValue) 
        public 
        returns (bool) 
    {
        require(isValidAddress(_spender), "Invalid spender");
        
        uint256 currentAllowance = accounts[msg.sender].allowances[_spender];
        uint256 newAllowance = safeAdd(currentAllowance, _addedValue);
        
        accounts[msg.sender].allowances[_spender] = newAllowance;
        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }
    
    // 函数式授权减少
    function decreaseAllowance(address _spender, uint256 _subtractedValue) 
        public 
        returns (bool) 
    {
        require(isValidAddress(_spender), "Invalid spender");
        
        uint256 currentAllowance = accounts[msg.sender].allowances[_spender];
        uint256 newAllowance = safeSub(currentAllowance, _subtractedValue);
        
        accounts[msg.sender].allowances[_spender] = newAllowance;
        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }
    
    // 函数式批量操作
    function batchTransfer(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) public returns (bool) {
        require(_recipients.length == _amounts.length, "Arrays length mismatch");
        require(_recipients.length <= 100, "Too many recipients");
        
        // 函数式验证所有输入
        uint256 totalAmount = _validateAndCalculateTotal(_recipients, _amounts);
        require(hasEnoughBalance(msg.sender, totalAmount), "Insufficient balance");
        
        // 执行所有转账
        for (uint256 i = 0; i < _recipients.length; i++) {
            _executeTransfer(msg.sender, _recipients[i], _amounts[i]);
        }
        
        return true;
    }
    
    // 纯函数 - 批量验证和计算
    function _validateAndCalculateTotal(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) private pure returns (uint256) {
        uint256 total = 0;
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(isValidAddress(_recipients[i]), "Invalid recipient");
            require(isValidAmount(_amounts[i]), "Invalid amount");
            total = safeAdd(total, _amounts[i]);
        }
        
        return total;
    }
    
    // 不可变交易历史记录
    function _recordTransaction(address _from, address _to, uint256 _amount) private {
        bytes32 txHash = keccak256(
            abi.encodePacked(_from, _to, _amount, block.timestamp, transactionHistory.length)
        );
        
        transactionHistory.push(Transaction({
            from: _from,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            txHash: txHash
        }));
        
        emit TransactionRecorded(txHash, _from, _to, _amount);
    }
    
    // 函数式查询 - 交易历史
    function getTransaction(uint256 _index) 
        public 
        view 
        returns (Transaction memory) 
    {
        require(_index < transactionHistory.length, "Invalid transaction index");
        return transactionHistory[_index];
    }
    
    function getTransactionCount() public view returns (uint256) {
        return transactionHistory.length;
    }
    
    // 函数式过滤 - 获取用户相关交易
    function getUserTransactions(address _user) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory userTxs = new uint256[](transactionHistory.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < transactionHistory.length; i++) {
            if (transactionHistory[i].from == _user || transactionHistory[i].to == _user) {
                userTxs[count] = i;
                count++;
            }
        }
        
        // 调整数组大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = userTxs[i];
        }
        
        return result;
    }
    
    // 函数式聚合 - 计算用户交易统计
    function getUserTransactionStats(address _user) 
        public 
        view 
        returns (
            uint256 totalTransactions,
            uint256 totalSent,
            uint256 totalReceived,
            uint256 lastTransactionTime
        ) 
    {
        uint256 txCount = 0;
        uint256 sent = 0;
        uint256 received = 0;
        
        for (uint256 i = 0; i < transactionHistory.length; i++) {
            Transaction memory tx = transactionHistory[i];
            
            if (tx.from == _user) {
                txCount++;
                sent = safeAdd(sent, tx.amount);
            }
            
            if (tx.to == _user) {
                txCount++;
                received = safeAdd(received, tx.amount);
            }
        }
        
        return (txCount, sent, received, accounts[_user].lastTransactionTime);
    }
    
    // 函数式账户信息
    function getAccountInfo(address _account) 
        public 
        view 
        returns (
            uint256 balance,
            bool isActive,
            uint256 lastTransactionTime
        ) 
    {
        Account storage account = accounts[_account];
        return (account.balance, account.isActive, account.lastTransactionTime);
    }
}

/*
函数式编程代币特色：

1. 不可变数据结构
   - 代币信息不可变
   - 交易历史不可变
   - 状态更新创建新状态

2. 纯函数设计
   - 验证函数无副作用
   - 数学运算函数纯净
   - 可预测的计算结果

3. 函数组合
   - 修饰符组合验证
   - 复杂操作由简单函数组成
   - 高阶函数概念应用

4. 声明式编程
   - 描述性的函数名
   - 表达式优于语句
   - 函数式数据处理

5. 历史记录不可变
   - 完整的交易历史
   - 不可篡改的记录
   - 函数式查询和过滤

这种设计体现了函数式编程在区块链中的应用：
纯函数、不可变性、函数组合、声明式编程。
*/