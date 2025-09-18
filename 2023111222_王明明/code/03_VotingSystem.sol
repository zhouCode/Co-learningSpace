// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 实用简洁投票系统
 * @dev 注重实用性的投票合约实现
 * @author 王明明 (2023111222)
 */

contract PracticalVoting {
    // 核心数据结构
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
        address proposer;
    }
    
    // 状态变量
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public isVoter;
    
    uint256 public proposalCount;
    address public admin;
    uint256 public votingDuration = 7 days;
    uint256 public minVoters = 3;
    
    // 实用事件
    event ProposalCreated(uint256 indexed proposalId, string description, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event VoterAdded(address voter);
    event VoterRemoved(address voter);
    
    // 简洁修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }
    
    modifier onlyVoter() {
        require(isVoter[msg.sender], "Not authorized voter");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal");
        _;
    }
    
    modifier votingActive(uint256 _proposalId) {
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting ended");
        require(!proposals[_proposalId].executed, "Already executed");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        isVoter[msg.sender] = true;
    }
    
    /**
     * @dev 添加投票者
     */
    function addVoter(address _voter) public onlyAdmin {
        require(_voter != address(0), "Invalid address");
        require(!isVoter[_voter], "Already a voter");
        
        isVoter[_voter] = true;
        emit VoterAdded(_voter);
    }
    
    /**
     * @dev 移除投票者
     */
    function removeVoter(address _voter) public onlyAdmin {
        require(isVoter[_voter], "Not a voter");
        require(_voter != admin, "Cannot remove admin");
        
        isVoter[_voter] = false;
        emit VoterRemoved(_voter);
    }
    
    /**
     * @dev 批量添加投票者 - 实用功能
     */
    function addVoters(address[] memory _voters) public onlyAdmin {
        require(_voters.length <= 50, "Too many voters");
        
        for (uint256 i = 0; i < _voters.length; i++) {
            if (_voters[i] != address(0) && !isVoter[_voters[i]]) {
                isVoter[_voters[i]] = true;
                emit VoterAdded(_voters[i]);
            }
        }
    }
    
    /**
     * @dev 创建提案
     */
    function createProposal(string memory _description) public onlyVoter returns (uint256) {
        require(bytes(_description).length > 0, "Empty description");
        require(bytes(_description).length <= 500, "Description too long");
        
        uint256 proposalId = proposalCount++;
        
        proposals[proposalId] = Proposal({
            description: _description,
            yesVotes: 0,
            noVotes: 0,
            deadline: block.timestamp + votingDuration,
            executed: false,
            proposer: msg.sender
        });
        
        emit ProposalCreated(proposalId, _description, msg.sender);
        return proposalId;
    }
    
    /**
     * @dev 投票
     */
    function vote(uint256 _proposalId, bool _support) 
        public 
        onlyVoter 
        validProposal(_proposalId) 
        votingActive(_proposalId) 
    {
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        
        hasVoted[_proposalId][msg.sender] = true;
        
        if (_support) {
            proposals[_proposalId].yesVotes++;
        } else {
            proposals[_proposalId].noVotes++;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support);
    }
    
    /**
     * @dev 执行提案
     */
    function executeProposal(uint256 _proposalId) 
        public 
        validProposal(_proposalId) 
        returns (bool) 
    {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp > proposal.deadline, "Voting still active");
        require(!proposal.executed, "Already executed");
        
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        require(totalVotes >= minVoters, "Not enough votes");
        
        proposal.executed = true;
        bool passed = proposal.yesVotes > proposal.noVotes;
        
        emit ProposalExecuted(_proposalId, passed);
        return passed;
    }
    
    /**
     * @dev 获取提案详情
     */
    function getProposal(uint256 _proposalId) 
        public 
        view 
        validProposal(_proposalId) 
        returns (
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 deadline,
            bool executed,
            address proposer,
            bool isActive
        ) 
    {
        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.deadline,
            proposal.executed,
            proposal.proposer,
            block.timestamp <= proposal.deadline && !proposal.executed
        );
    }
    
    /**
     * @dev 获取投票结果
     */
    function getVoteResult(uint256 _proposalId) 
        public 
        view 
        validProposal(_proposalId) 
        returns (
            uint256 yesVotes,
            uint256 noVotes,
            uint256 totalVotes,
            bool passed,
            bool canExecute
        ) 
    {
        Proposal memory proposal = proposals[_proposalId];
        uint256 total = proposal.yesVotes + proposal.noVotes;
        
        return (
            proposal.yesVotes,
            proposal.noVotes,
            total,
            proposal.yesVotes > proposal.noVotes,
            block.timestamp > proposal.deadline && !proposal.executed && total >= minVoters
        );
    }
    
    /**
     * @dev 获取活跃提案列表 - 实用功能
     */
    function getActiveProposals() public view returns (uint256[] memory) {
        uint256[] memory activeIds = new uint256[](proposalCount);
        uint256 count = 0;
        
        for (uint256 i = 0; i < proposalCount; i++) {
            if (block.timestamp <= proposals[i].deadline && !proposals[i].executed) {
                activeIds[count] = i;
                count++;
            }
        }
        
        // 调整数组大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev 检查用户是否已投票
     */
    function hasUserVoted(uint256 _proposalId, address _user) 
        public 
        view 
        validProposal(_proposalId) 
        returns (bool) 
    {
        return hasVoted[_proposalId][_user];
    }
    
    /**
     * @dev 设置投票持续时间
     */
    function setVotingDuration(uint256 _duration) public onlyAdmin {
        require(_duration >= 1 hours && _duration <= 30 days, "Invalid duration");
        votingDuration = _duration;
    }
    
    /**
     * @dev 设置最小投票人数
     */
    function setMinVoters(uint256 _minVoters) public onlyAdmin {
        require(_minVoters > 0, "Invalid min voters");
        minVoters = _minVoters;
    }
    
    /**
     * @dev 获取系统信息
     */
    function getSystemInfo() public view returns (
        uint256 totalProposals,
        uint256 votingDuration_,
        uint256 minVoters_,
        address admin_
    ) {
        return (proposalCount, votingDuration, minVoters, admin);
    }
    
    /**
     * @dev 转移管理权
     */
    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        admin = _newAdmin;
        isVoter[_newAdmin] = true;
    }
}

/*
实用简洁投票系统特色：

1. 功能完整性
   - 基本投票流程
   - 提案管理
   - 投票者管理

2. 实用功能
   - 批量添加投票者
   - 活跃提案查询
   - 投票状态检查

3. 简洁设计
   - 直接的数据结构
   - 清晰的状态管理
   - 简单的权限控制

4. 易用性
   - 直观的接口设计
   - 完整的查询功能
   - 清晰的事件日志

5. 可配置性
   - 可调整投票时间
   - 可设置最小投票数
   - 灵活的权限管理

这种设计体现了实用主义：
功能齐全、操作简单、易于理解和使用。
*/