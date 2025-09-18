// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 实用简洁代币合约
 * @dev 注重实用性的ERC20代币实现
 * @author 王明明 (2023111222)
 */

contract PracticalToken {
    // 核心状态变量
    string public name = "Practical Token";
    string public symbol = "PRAC";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    bool public paused = false;
    
    // 实用事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Pause();
    event Unpause();
    
    // 简洁修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    /**
     * @dev 标准转账功能
     */
    function transfer(address _to, uint256 _value) 
        public 
        whenNotPaused 
        validAddress(_to) 
        returns (bool) 
    {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    /**
     * @dev 授权转账
     */
    function transferFrom(address _from, address _to, uint256 _value) 
        public 
        whenNotPaused 
        validAddress(_to) 
        returns (bool) 
    {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    /**
     * @dev 批准授权
     */
    function approve(address _spender, uint256 _value) 
        public 
        validAddress(_spender) 
        returns (bool) 
    {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    /**
     * @dev 增加授权额度
     */
    function increaseAllowance(address _spender, uint256 _addedValue) 
        public 
        validAddress(_spender) 
        returns (bool) 
    {
        allowance[msg.sender][_spender] += _addedValue;
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }
    
    /**
     * @dev 减少授权额度
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) 
        public 
        validAddress(_spender) 
        returns (bool) 
    {
        uint256 currentAllowance = allowance[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "Decreased allowance below zero");
        
        allowance[msg.sender][_spender] = currentAllowance - _subtractedValue;
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }
    
    /**
     * @dev 铸造代币 - 实用的管理功能
     */
    function mint(address _to, uint256 _amount) 
        public 
        onlyOwner 
        validAddress(_to) 
        returns (bool) 
    {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        
        emit Transfer(address(0), _to, _amount);
        emit Mint(_to, _amount);
        return true;
    }
    
    /**
     * @dev 销毁代币
     */
    function burn(uint256 _amount) public returns (bool) {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        
        emit Transfer(msg.sender, address(0), _amount);
        emit Burn(msg.sender, _amount);
        return true;
    }
    
    /**
     * @dev 批量转账 - 实用功能
     */
    function batchTransfer(address[] memory _recipients, uint256[] memory _amounts) 
        public 
        whenNotPaused 
        returns (bool) 
    {
        require(_recipients.length == _amounts.length, "Arrays length mismatch");
        require(_recipients.length <= 100, "Too many recipients");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }
        
        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance");
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipient");
            
            balanceOf[msg.sender] -= _amounts[i];
            balanceOf[_recipients[i]] += _amounts[i];
            
            emit Transfer(msg.sender, _recipients[i], _amounts[i]);
        }
        
        return true;
    }
    
    /**
     * @dev 暂停/恢复合约
     */
    function pause() public onlyOwner {
        paused = true;
        emit Pause();
    }
    
    function unpause() public onlyOwner {
        paused = false;
        emit Unpause();
    }
    
    /**
     * @dev 转移所有权
     */
    function transferOwnership(address _newOwner) public onlyOwner validAddress(_newOwner) {
        owner = _newOwner;
    }
    
    /**
     * @dev 获取代币信息
     */
    function getTokenInfo() public view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        bool paused_
    ) {
        return (name, symbol, decimals, totalSupply, paused);
    }
    
    /**
     * @dev 检查余额是否足够
     */
    function hasEnoughBalance(address _account, uint256 _amount) 
        public 
        view 
        returns (bool) 
    {
        return balanceOf[_account] >= _amount;
    }
}

/*
实用简洁代币设计特色：

1. 功能完整性
   - 标准ERC20接口
   - 实用的管理功能
   - 批量操作支持

2. 代码简洁
   - 直接的实现方式
   - 最少的状态变量
   - 清晰的逻辑结构

3. 实用功能
   - 批量转账
   - 暂停机制
   - 余额检查

4. 安全考虑
   - 基本的访问控制
   - 输入验证
   - 溢出保护

5. 易用性
   - 简单的接口
   - 清晰的错误信息
   - 实用的查询功能

这种设计体现了实用主义：
功能完整、实现简洁、易于使用和维护。
*/