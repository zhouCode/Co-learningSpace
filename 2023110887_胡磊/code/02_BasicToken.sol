// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 创新型基础代币合约
 * @dev 集成多种创新机制的ERC20代币
 * @author 胡磊 (2023110887)
 * @notice 这是一个具有创新特性的代币合约，包含动态供应、社区治理等功能
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

contract InnovativeToken is IERC20 {
    // 基础代币信息
    string public name = "InnovaCoin";
    string public symbol = "INNO";
    uint8 public decimals = 18;
    uint256 private _totalSupply;
    
    // 创新特性：动态供应机制
    uint256 public maxSupply = 1000000 * 10**decimals;
    uint256 public mintRate = 100 * 10**decimals; // 每次铸造数量
    uint256 public lastMintTime;
    uint256 public mintInterval = 1 days; // 铸造间隔
    
    // 创新特性：持有者奖励系统
    mapping(address => uint256) public lastActivityTime;
    mapping(address => uint256) public loyaltyPoints;
    uint256 public loyaltyRewardRate = 1; // 每天1个积分
    
    // 创新特性：社区治理
    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        address proposer;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    
    // 创新特性：交易费用池
    uint256 public feePool;
    uint256 public transactionFeeRate = 10; // 0.1% (10/10000)
    bool public feesEnabled = true;
    
    // 标准ERC20映射
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // 权限管理
    address public owner;
    mapping(address => bool) public minters;
    
    // 事件
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event LoyaltyReward(address indexed user, uint256 points);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event FeeCollected(address indexed from, address indexed to, uint256 fee);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner, "Not authorized to mint");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        minters[msg.sender] = true;
        _totalSupply = 100000 * 10**decimals; // 初始供应量
        _balances[msg.sender] = _totalSupply;
        lastMintTime = block.timestamp;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    
    // 标准ERC20函数
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    // 创新功能：智能转账（包含费用和奖励机制）
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        // 计算交易费用
        uint256 fee = 0;
        if (feesEnabled && from != owner && to != owner) {
            fee = (amount * transactionFeeRate) / 10000;
            if (fee > 0) {
                feePool += fee;
                emit FeeCollected(from, to, fee);
            }
        }
        
        uint256 transferAmount = amount - fee;
        
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += transferAmount;
        
        // 更新活动时间和忠诚度积分
        _updateActivity(from);
        _updateActivity(to);
        
        emit Transfer(from, to, transferAmount);
        if (fee > 0) {
            emit Transfer(from, address(this), fee);
        }
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
    
    // 创新功能：动态铸造
    function autoMint() public {
        require(block.timestamp >= lastMintTime + mintInterval, "Mint interval not reached");
        require(_totalSupply + mintRate <= maxSupply, "Max supply reached");
        
        _totalSupply += mintRate;
        _balances[owner] += mintRate;
        lastMintTime = block.timestamp;
        
        emit Mint(owner, mintRate);
        emit Transfer(address(0), owner, mintRate);
    }
    
    // 创新功能：忠诚度系统
    function _updateActivity(address user) internal {
        if (user != address(0) && user != address(this)) {
            uint256 timeSinceLastActivity = block.timestamp - lastActivityTime[user];
            if (timeSinceLastActivity >= 1 days) {
                uint256 daysActive = timeSinceLastActivity / 1 days;
                loyaltyPoints[user] += daysActive * loyaltyRewardRate;
                emit LoyaltyReward(user, daysActive * loyaltyRewardRate);
            }
            lastActivityTime[user] = block.timestamp;
        }
    }
    
    function claimLoyaltyReward() public {
        uint256 points = loyaltyPoints[msg.sender];
        require(points > 0, "No loyalty points to claim");
        
        uint256 rewardAmount = points * 10**decimals; // 1 point = 1 token
        require(_totalSupply + rewardAmount <= maxSupply, "Max supply would be exceeded");
        
        loyaltyPoints[msg.sender] = 0;
        _totalSupply += rewardAmount;
        _balances[msg.sender] += rewardAmount;
        
        emit Mint(msg.sender, rewardAmount);
        emit Transfer(address(0), msg.sender, rewardAmount);
    }
    
    // 创新功能：社区治理
    function createProposal(string memory description) public returns (uint256) {
        require(_balances[msg.sender] >= 1000 * 10**decimals, "Insufficient tokens to create proposal");
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + votingPeriod,
            executed: false,
            proposer: msg.sender
        });
        
        emit ProposalCreated(proposalCount, msg.sender, description);
        return proposalCount;
    }
    
    function vote(uint256 proposalId, bool support) public {
        require(proposalId <= proposalCount, "Invalid proposal ID");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period ended");
        
        uint256 votingPower = _balances[msg.sender];
        require(votingPower > 0, "No voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].forVotes += votingPower;
        } else {
            proposals[proposalId].againstVotes += votingPower;
        }
        
        emit Voted(proposalId, msg.sender, support, votingPower);
    }
    
    // 创新功能：费用分配
    function distributeFees() public onlyOwner {
        require(feePool > 0, "No fees to distribute");
        
        uint256 amount = feePool;
        feePool = 0;
        
        // 50%给持有者，50%销毁
        uint256 holderReward = amount / 2;
        uint256 burnAmount = amount - holderReward;
        
        _balances[owner] += holderReward;
        _totalSupply -= burnAmount;
        
        emit Transfer(address(this), owner, holderReward);
        emit Transfer(address(this), address(0), burnAmount);
        emit Burn(address(this), burnAmount);
    }
    
    // 管理功能
    function setMinter(address minter, bool status) public onlyOwner {
        minters[minter] = status;
    }
    
    function setFeeRate(uint256 newRate) public onlyOwner {
        require(newRate <= 100, "Fee rate too high"); // 最大1%
        transactionFeeRate = newRate;
    }
    
    function toggleFees() public onlyOwner {
        feesEnabled = !feesEnabled;
    }
    
    // 查询功能
    function getProposal(uint256 proposalId) public view returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }
    
    function getUserInfo(address user) public view returns (
        uint256 balance,
        uint256 loyaltyPoints_,
        uint256 lastActivity
    ) {
        return (
            _balances[user],
            loyaltyPoints[user],
            lastActivityTime[user]
        );
    }
}

/*
创新设计特色：

1. 动态供应机制
   - 定时自动铸造
   - 供应量上限控制
   - 通胀率可调节

2. 忠诚度奖励系统
   - 基于活跃度的积分
   - 积分兑换代币
   - 长期持有激励

3. 社区治理功能
   - 提案创建机制
   - 基于持币量的投票
   - 民主决策过程

4. 智能费用系统
   - 交易费用收集
   - 费用分配机制
   - 通缩销毁机制

5. 用户体验优化
   - 活动时间跟踪
   - 多维度用户信息
   - 透明的统计数据

这种设计体现了现代DeFi项目的核心理念：
社区驱动、价值捕获、可持续发展。
*/