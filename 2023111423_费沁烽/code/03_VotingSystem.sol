// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 函数式编程风格投票系统
 * @dev 采用函数式编程理念的投票合约实现
 * @author 费沁烽 (2023111423)
 */

contract FunctionalVoting {
    // 不可变投票配置
    struct VotingConfig {
        uint256 votingDuration;
        uint256 minQuorum;
        uint256 passingThreshold; // 百分比
        bool requiresRegistration;
    }
    
    // 不可变提案数据
    struct Proposal {
        bytes32 id;
        string description;
        address proposer;
        uint256 createdAt;
        uint256 deadline;
        ProposalState state;
        VoteResult result;
    }
    
    // 投票结果 - 不可变记录
    struct VoteResult {
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        uint256 totalVoters;
        bool executed;
        uint256 executedAt;
    }
    
    // 投票者状态
    struct Voter {
        bool isRegistered;
        uint256 registeredAt;
        uint256 votingPower;
        mapping(bytes32 => Vote) votes;
    }
    
    // 单次投票记录 - 不可变
    struct Vote {
        VoteChoice choice;
        uint256 timestamp;
        uint256 power;
        bool isValid;
    }
    
    enum ProposalState { Active, Passed, Rejected, Executed, Expired }
    enum VoteChoice { None, Yes, No, Abstain }
    
    VotingConfig private immutable config;
    mapping(bytes32 => Proposal) private proposals;
    mapping(address => Voter) private voters;
    bytes32[] private proposalIds;
    address private immutable admin;
    
    // 函数式事件
    event ProposalCreated(bytes32 indexed proposalId, address proposer, string description);
    event VoteCast(bytes32 indexed proposalId, address voter, VoteChoice choice, uint256 power);
    event ProposalStateChanged(bytes32 indexed proposalId, ProposalState oldState, ProposalState newState);
    event VoterRegistered(address voter, uint256 votingPower);
    
    // 函数式修饰符 - 高阶函数概念
    modifier pure_proposal_validation(
        function(string memory) pure returns (bool) validator,
        string memory description
    ) {
        require(validator(description), "Proposal validation failed");
        _;
    }
    
    modifier compose_voting_checks(
        bytes32 proposalId,
        address voter
    ) {
        require(
            isValidProposal(proposalId) &&
            isRegisteredVoter(voter) &&
            isVotingActive(proposalId) &&
            !hasVoted(proposalId, voter),
            "Voting validation failed"
        );
        _;
    }
    
    constructor(
        uint256 _votingDuration,
        uint256 _minQuorum,
        uint256 _passingThreshold,
        bool _requiresRegistration
    ) {
        config = VotingConfig({
            votingDuration: _votingDuration,
            minQuorum: _minQuorum,
            passingThreshold: _passingThreshold,
            requiresRegistration: _requiresRegistration
        });
        
        admin = msg.sender;
        
        // 管理员自动注册
        voters[msg.sender].isRegistered = true;
        voters[msg.sender].registeredAt = block.timestamp;
        voters[msg.sender].votingPower = 1;
    }
    
    // 纯函数 - 验证函数
    function isValidDescription(string memory _description) public pure returns (bool) {
        bytes memory desc = bytes(_description);
        return desc.length > 0 && desc.length <= 1000;
    }
    
    function isValidProposal(bytes32 _proposalId) public view returns (bool) {
        return proposals[_proposalId].createdAt > 0;
    }
    
    function isRegisteredVoter(address _voter) public view returns (bool) {
        return !config.requiresRegistration || voters[_voter].isRegistered;
    }
    
    function isVotingActive(bytes32 _proposalId) public view returns (bool) {
        Proposal memory proposal = proposals[_proposalId];
        return block.timestamp <= proposal.deadline && 
               proposal.state == ProposalState.Active;
    }
    
    function hasVoted(bytes32 _proposalId, address _voter) public view returns (bool) {
        return voters[_voter].votes[_proposalId].choice != VoteChoice.None;
    }
    
    // 纯函数 - 计算函数
    function calculateDeadline(uint256 _createdAt) public view returns (uint256) {
        return _createdAt + config.votingDuration;
    }
    
    function calculateVotingPower(address _voter) public view returns (uint256) {
        if (!voters[_voter].isRegistered) return 0;
        
        // 基于注册时间的投票权重（简化版）
        uint256 timeSinceRegistration = block.timestamp - voters[_voter].registeredAt;
        uint256 basePower = voters[_voter].votingPower;
        
        // 注册越久，权重略微增加（最多2倍）
        uint256 timeBonus = timeSinceRegistration / (30 days);
        return basePower + (timeBonus > basePower ? basePower : timeBonus);
    }
    
    function calculateQuorum(uint256 _totalVoters) public view returns (bool) {
        return _totalVoters >= config.minQuorum;
    }
    
    function calculatePassed(uint256 _yesVotes, uint256 _totalVotes) public view returns (bool) {
        if (_totalVotes == 0) return false;
        return (_yesVotes * 100) / _totalVotes >= config.passingThreshold;
    }
    
    // 函数式提案创建
    function createProposal(string memory _description) 
        public 
        pure_proposal_validation(isValidDescription, _description)
        returns (bytes32) 
    {
        require(isRegisteredVoter(msg.sender), "Not registered voter");
        
        bytes32 proposalId = _generateProposalId(_description, msg.sender);
        uint256 createdAt = block.timestamp;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            description: _description,
            proposer: msg.sender,
            createdAt: createdAt,
            deadline: calculateDeadline(createdAt),
            state: ProposalState.Active,
            result: VoteResult({
                yesVotes: 0,
                noVotes: 0,
                abstainVotes: 0,
                totalVoters: 0,
                executed: false,
                executedAt: 0
            })
        });
        
        proposalIds.push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }
    
    // 纯函数 - 提案ID生成
    function _generateProposalId(string memory _description, address _proposer) 
        private 
        view 
        returns (bytes32) 
    {
        return keccak256(
            abi.encodePacked(_description, _proposer, block.timestamp, proposalIds.length)
        );
    }
    
    // 函数式投票
    function vote(bytes32 _proposalId, VoteChoice _choice) 
        public 
        compose_voting_checks(_proposalId, msg.sender)
        returns (bool) 
    {
        require(_choice != VoteChoice.None, "Invalid vote choice");
        
        uint256 votingPower = calculateVotingPower(msg.sender);
        
        // 记录不可变投票
        voters[msg.sender].votes[_proposalId] = Vote({
            choice: _choice,
            timestamp: block.timestamp,
            power: votingPower,
            isValid: true
        });
        
        // 更新提案结果
        _updateProposalResult(_proposalId, _choice, votingPower);
        
        emit VoteCast(_proposalId, msg.sender, _choice, votingPower);
        return true;
    }
    
    // 内部函数 - 更新提案结果
    function _updateProposalResult(
        bytes32 _proposalId, 
        VoteChoice _choice, 
        uint256 _power
    ) private {
        VoteResult storage result = proposals[_proposalId].result;
        
        if (_choice == VoteChoice.Yes) {
            result.yesVotes += _power;
        } else if (_choice == VoteChoice.No) {
            result.noVotes += _power;
        } else if (_choice == VoteChoice.Abstain) {
            result.abstainVotes += _power;
        }
        
        result.totalVoters += 1;
    }
    
    // 函数式提案执行
    function executeProposal(bytes32 _proposalId) public returns (ProposalState) {
        require(isValidProposal(_proposalId), "Invalid proposal");
        
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.deadline, "Voting still active");
        require(proposal.state == ProposalState.Active, "Proposal not active");
        
        ProposalState oldState = proposal.state;
        ProposalState newState = _calculateProposalState(_proposalId);
        
        proposal.state = newState;
        
        if (newState == ProposalState.Executed) {
            proposal.result.executed = true;
            proposal.result.executedAt = block.timestamp;
        }
        
        emit ProposalStateChanged(_proposalId, oldState, newState);
        return newState;
    }
    
    // 纯函数式状态计算
    function _calculateProposalState(bytes32 _proposalId) 
        private 
        view 
        returns (ProposalState) 
    {
        VoteResult memory result = proposals[_proposalId].result;
        
        if (!calculateQuorum(result.totalVoters)) {
            return ProposalState.Expired;
        }
        
        uint256 totalVotes = result.yesVotes + result.noVotes + result.abstainVotes;
        
        if (calculatePassed(result.yesVotes, totalVotes)) {
            return ProposalState.Passed;
        } else {
            return ProposalState.Rejected;
        }
    }
    
    // 函数式投票者注册
    function registerVoter(address _voter, uint256 _votingPower) public returns (bool) {
        require(msg.sender == admin, "Only admin can register");
        require(_voter != address(0), "Invalid voter address");
        require(!voters[_voter].isRegistered, "Already registered");
        require(_votingPower > 0, "Invalid voting power");
        
        voters[_voter].isRegistered = true;
        voters[_voter].registeredAt = block.timestamp;
        voters[_voter].votingPower = _votingPower;
        
        emit VoterRegistered(_voter, _votingPower);
        return true;
    }
    
    // 函数式批量注册
    function batchRegisterVoters(
        address[] memory _voters,
        uint256[] memory _powers
    ) public returns (bool) {
        require(msg.sender == admin, "Only admin can register");
        require(_voters.length == _powers.length, "Arrays length mismatch");
        require(_voters.length <= 100, "Too many voters");
        
        for (uint256 i = 0; i < _voters.length; i++) {
            if (_voters[i] != address(0) && 
                !voters[_voters[i]].isRegistered && 
                _powers[i] > 0) {
                
                voters[_voters[i]].isRegistered = true;
                voters[_voters[i]].registeredAt = block.timestamp;
                voters[_voters[i]].votingPower = _powers[i];
                
                emit VoterRegistered(_voters[i], _powers[i]);
            }
        }
        
        return true;
    }
    
    // 函数式查询 - 不可变视图
    function getProposal(bytes32 _proposalId) 
        public 
        view 
        returns (Proposal memory) 
    {
        require(isValidProposal(_proposalId), "Invalid proposal");
        return proposals[_proposalId];
    }
    
    function getVote(bytes32 _proposalId, address _voter) 
        public 
        view 
        returns (Vote memory) 
    {
        return voters[_voter].votes[_proposalId];
    }
    
    function getVoterInfo(address _voter) 
        public 
        view 
        returns (
            bool isRegistered,
            uint256 registeredAt,
            uint256 votingPower,
            uint256 currentPower
        ) 
    {
        Voter storage voter = voters[_voter];
        return (
            voter.isRegistered,
            voter.registeredAt,
            voter.votingPower,
            calculateVotingPower(_voter)
        );
    }
    
    // 函数式过滤 - 获取活跃提案
    function getActiveProposals() public view returns (bytes32[] memory) {
        bytes32[] memory activeProposals = new bytes32[](proposalIds.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (isVotingActive(proposalIds[i])) {
                activeProposals[count] = proposalIds[i];
                count++;
            }
        }
        
        // 调整数组大小
        bytes32[] memory result = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeProposals[i];
        }
        
        return result;
    }
    
    // 函数式聚合 - 统计信息
    function getSystemStats() 
        public 
        view 
        returns (
            uint256 totalProposals,
            uint256 activeProposals,
            uint256 passedProposals,
            uint256 rejectedProposals
        ) 
    {
        uint256 active = 0;
        uint256 passed = 0;
        uint256 rejected = 0;
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            ProposalState state = proposals[proposalIds[i]].state;
            
            if (state == ProposalState.Active) active++;
            else if (state == ProposalState.Passed || state == ProposalState.Executed) passed++;
            else if (state == ProposalState.Rejected) rejected++;
        }
        
        return (proposalIds.length, active, passed, rejected);
    }
    
    // 函数式配置查询
    function getConfig() public view returns (VotingConfig memory) {
        return config;
    }
    
    function getAllProposalIds() public view returns (bytes32[] memory) {
        return proposalIds;
    }
}

/*
函数式编程投票系统特色：

1. 不可变数据结构
   - 配置信息不可变
   - 投票记录不可变
   - 提案状态历史完整

2. 纯函数设计
   - 验证函数无副作用
   - 计算函数可预测
   - 状态转换函数纯净

3. 函数组合
   - 复杂验证由简单函数组成
   - 修饰符组合多重检查
   - 高阶函数概念应用

4. 声明式编程
   - 描述性的函数名
   - 表达式优于语句
   - 函数式数据处理

5. 函数式操作
   - 映射操作获取数据
   - 过滤操作筛选提案
   - 聚合操作统计信息

这种设计体现了函数式编程在治理系统中的应用：
纯函数、不可变性、函数组合、声明式编程。
*/