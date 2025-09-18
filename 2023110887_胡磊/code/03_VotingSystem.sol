// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 创新型投票治理系统
 * @dev 集成多种创新治理机制的智能投票合约
 * @author 胡磊 (2023110887)
 * @notice 这是一个具有创新特性的投票系统，支持多种投票模式和治理机制
 */

contract InnovativeVotingSystem {
    // 投票类型枚举
    enum VoteType { Simple, Weighted, Quadratic, Delegated }
    enum ProposalStatus { Pending, Active, Passed, Rejected, Executed, Cancelled }
    
    // 提案结构
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        VoteType voteType;
        ProposalStatus status;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 quorum;
        uint256 threshold; // 通过阈值（百分比）
        bytes executionData;
        address targetContract;
        bool executed;
    }
    
    // 投票者信息
    struct Voter {
        bool isRegistered;
        uint256 votingPower;
        uint256 delegatedPower;
        address delegate;
        uint256 reputation;
        uint256 participationCount;
        mapping(uint256 => bool) hasVoted;
        mapping(uint256 => VoteChoice) votes;
    }
    
    // 投票选择
    struct VoteChoice {
        bool support; // true=赞成, false=反对
        bool abstain; // 弃权
        uint256 weight;
        string reason;
        uint256 timestamp;
    }
    
    // 委托信息
    struct Delegation {
        address delegator;
        address delegate;
        uint256 power;
        uint256 timestamp;
        bool active;
    }
    
    // 状态变量
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(address => mapping(address => uint256)) public delegations;
    mapping(uint256 => mapping(address => VoteChoice)) public votes;
    
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    uint256 public minimumQuorum = 1000; // 最小法定人数
    uint256 public proposalDeposit = 100 ether; // 提案押金
    
    // 创新特性：动态参数
    uint256 public baseVotingPeriod = 7 days;
    uint256 public reputationMultiplier = 100;
    uint256 public participationReward = 10;
    
    // 创新特性：投票激励池
    uint256 public incentivePool;
    mapping(address => uint256) public pendingRewards;
    
    // 权限管理
    address public admin;
    mapping(address => bool) public moderators;
    
    // 事件
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        VoteType voteType
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight,
        string reason
    );
    
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event VoterRegistered(address indexed voter, uint256 votingPower);
    event PowerDelegated(address indexed delegator, address indexed delegate, uint256 power);
    event ReputationUpdated(address indexed voter, uint256 newReputation);
    event IncentiveDistributed(address indexed voter, uint256 amount);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    modifier onlyModerator() {
        require(moderators[msg.sender] || msg.sender == admin, "Only moderator");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Not registered voter");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        moderators[msg.sender] = true;
    }
    
    // 创新功能：多模式投票者注册
    function registerVoter(
        address voter,
        uint256 initialPower,
        uint256 initialReputation
    ) public onlyModerator {
        require(!voters[voter].isRegistered, "Already registered");
        require(initialPower > 0, "Power must be positive");
        
        voters[voter].isRegistered = true;
        voters[voter].votingPower = initialPower;
        voters[voter].reputation = initialReputation;
        totalVotingPower += initialPower;
        
        emit VoterRegistered(voter, initialPower);
    }
    
    // 创新功能：智能提案创建
    function createProposal(
        string memory title,
        string memory description,
        VoteType voteType,
        uint256 duration,
        uint256 quorum,
        uint256 threshold,
        address targetContract,
        bytes memory executionData
    ) public payable onlyRegisteredVoter returns (uint256) {
        require(msg.value >= proposalDeposit, "Insufficient deposit");
        require(duration >= 1 days && duration <= 30 days, "Invalid duration");
        require(threshold >= 50 && threshold <= 100, "Invalid threshold");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            voteType: voteType,
            status: ProposalStatus.Active,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            quorum: quorum > 0 ? quorum : minimumQuorum,
            threshold: threshold,
            executionData: executionData,
            targetContract: targetContract,
            executed: false
        });
        
        // 将押金加入激励池
        incentivePool += msg.value;
        
        emit ProposalCreated(proposalId, msg.sender, title, voteType);
        return proposalId;
    }
    
    // 创新功能：多模式投票
    function vote(
        uint256 proposalId,
        bool support,
        bool abstain,
        string memory reason
    ) public onlyRegisteredVoter {
        require(proposalId <= proposalCount, "Invalid proposal");
        require(!voters[msg.sender].hasVoted[proposalId], "Already voted");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        
        uint256 votingWeight = calculateVotingWeight(msg.sender, proposalId, proposal.voteType);
        require(votingWeight > 0, "No voting power");
        
        // 记录投票
        voters[msg.sender].hasVoted[proposalId] = true;
        voters[msg.sender].votes[proposalId] = VoteChoice({
            support: support,
            abstain: abstain,
            weight: votingWeight,
            reason: reason,
            timestamp: block.timestamp
        });
        
        votes[proposalId][msg.sender] = voters[msg.sender].votes[proposalId];
        
        // 更新投票统计
        if (abstain) {
            proposal.abstainVotes += votingWeight;
        } else if (support) {
            proposal.forVotes += votingWeight;
        } else {
            proposal.againstVotes += votingWeight;
        }
        
        // 更新参与统计和声誉
        voters[msg.sender].participationCount++;
        _updateReputation(msg.sender, true);
        
        // 分配参与奖励
        pendingRewards[msg.sender] += participationReward;
        
        emit VoteCast(proposalId, msg.sender, support, votingWeight, reason);
        
        // 检查是否可以提前结束投票
        _checkEarlyCompletion(proposalId);
    }
    
    // 创新功能：动态投票权重计算
    function calculateVotingWeight(
        address voter,
        uint256 proposalId,
        VoteType voteType
    ) public view returns (uint256) {
        Voter storage v = voters[voter];
        uint256 basePower = v.votingPower + v.delegatedPower;
        
        if (voteType == VoteType.Simple) {
            return basePower;
        } else if (voteType == VoteType.Weighted) {
            // 基于声誉的加权投票
            return basePower * (100 + v.reputation) / 100;
        } else if (voteType == VoteType.Quadratic) {
            // 二次投票：权重 = sqrt(power)
            return sqrt(basePower);
        } else if (voteType == VoteType.Delegated) {
            // 委托投票：包含委托给自己的权力
            return basePower;
        }
        
        return basePower;
    }
    
    // 创新功能：权力委托系统
    function delegatePower(address delegate, uint256 amount) public onlyRegisteredVoter {
        require(delegate != msg.sender, "Cannot delegate to self");
        require(voters[delegate].isRegistered, "Delegate not registered");
        require(voters[msg.sender].votingPower >= amount, "Insufficient power");
        
        voters[msg.sender].votingPower -= amount;
        voters[msg.sender].delegate = delegate;
        voters[delegate].delegatedPower += amount;
        delegations[msg.sender][delegate] += amount;
        
        emit PowerDelegated(msg.sender, delegate, amount);
    }
    
    function revokeDelegation(address delegate, uint256 amount) public onlyRegisteredVoter {
        require(delegations[msg.sender][delegate] >= amount, "Insufficient delegation");
        
        delegations[msg.sender][delegate] -= amount;
        voters[delegate].delegatedPower -= amount;
        voters[msg.sender].votingPower += amount;
        
        if (delegations[msg.sender][delegate] == 0) {
            voters[msg.sender].delegate = address(0);
        }
    }
    
    // 创新功能：智能提案执行
    function executeProposal(uint256 proposalId) public {
        require(proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        
        // 检查法定人数
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        require(totalVotes >= proposal.quorum, "Quorum not reached");
        
        // 检查通过阈值
        uint256 supportPercentage = (proposal.forVotes * 100) / (proposal.forVotes + proposal.againstVotes);
        
        if (supportPercentage >= proposal.threshold) {
            proposal.status = ProposalStatus.Passed;
            
            // 执行提案
            if (proposal.targetContract != address(0) && proposal.executionData.length > 0) {
                (bool success, ) = proposal.targetContract.call(proposal.executionData);
                proposal.executed = true;
                emit ProposalExecuted(proposalId, success);
            }
            
            // 奖励提案者
            pendingRewards[proposal.proposer] += proposalDeposit / 2;
            
        } else {
            proposal.status = ProposalStatus.Rejected;
        }
        
        // 分配投票奖励
        _distributeVotingRewards(proposalId);
    }
    
    // 创新功能：声誉系统更新
    function _updateReputation(address voter, bool participated) internal {
        if (participated) {
            voters[voter].reputation += 1;
        } else {
            // 不参与投票会降低声誉
            if (voters[voter].reputation > 0) {
                voters[voter].reputation -= 1;
            }
        }
        
        emit ReputationUpdated(voter, voters[voter].reputation);
    }
    
    // 创新功能：投票奖励分配
    function _distributeVotingRewards(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalParticipants = 0;
        
        // 计算参与者数量（简化实现）
        // 实际实现中需要遍历所有投票者
        uint256 rewardPerParticipant = incentivePool / 100; // 简化计算
        
        // 这里简化了奖励分配逻辑
        // 实际项目中需要更复杂的奖励算法
    }
    
    // 创新功能：提前结束检查
    function _checkEarlyCompletion(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        
        // 如果超过总投票权的80%已投票，可以提前结束
        if (totalVotes >= (totalVotingPower * 80) / 100) {
            proposal.endTime = block.timestamp;
        }
    }
    
    // 工具函数：平方根计算
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    // 查询功能
    function getProposalDetails(uint256 proposalId) public view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        ProposalStatus status,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.status,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes
        );
    }
    
    function getVoterInfo(address voter) public view returns (
        bool isRegistered,
        uint256 votingPower,
        uint256 delegatedPower,
        address delegate,
        uint256 reputation,
        uint256 participationCount,
        uint256 pendingReward
    ) {
        Voter storage v = voters[voter];
        return (
            v.isRegistered,
            v.votingPower,
            v.delegatedPower,
            v.delegate,
            v.reputation,
            v.participationCount,
            pendingRewards[voter]
        );
    }
    
    // 管理功能
    function addModerator(address moderator) public onlyAdmin {
        moderators[moderator] = true;
    }
    
    function removeModerator(address moderator) public onlyAdmin {
        moderators[moderator] = false;
    }
    
    function updateParameters(
        uint256 newMinimumQuorum,
        uint256 newProposalDeposit,
        uint256 newBaseVotingPeriod
    ) public onlyAdmin {
        minimumQuorum = newMinimumQuorum;
        proposalDeposit = newProposalDeposit;
        baseVotingPeriod = newBaseVotingPeriod;
    }
    
    // 紧急功能
    function emergencyPause(uint256 proposalId) public onlyAdmin {
        proposals[proposalId].status = ProposalStatus.Cancelled;
    }
    
    function withdrawIncentives() public {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "No rewards to withdraw");
        
        pendingRewards[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit IncentiveDistributed(msg.sender, amount);
    }
    
    // 接收以太币用于激励池
    receive() external payable {
        incentivePool += msg.value;
    }
}

/*
创新治理特色：

1. 多模式投票系统
   - 简单投票、加权投票、二次投票、委托投票
   - 动态权重计算
   - 灵活的投票机制

2. 智能声誉系统
   - 基于参与度的声誉积累
   - 声誉影响投票权重
   - 长期激励机制

3. 权力委托机制
   - 灵活的权力委托
   - 委托权力可撤回
   - 代理投票支持

4. 激励与奖励
   - 参与奖励机制
   - 提案押金系统
   - 动态奖励分配

5. 智能执行系统
   - 自动提案执行
   - 法定人数检查
   - 提前结束机制

这种设计体现了现代DAO治理的核心理念：
民主参与、激励相容、可持续发展。
*/