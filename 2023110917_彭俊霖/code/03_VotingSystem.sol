// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 安全导向投票系统
 * @dev 注重安全性的投票合约实现
 * @author 彭俊霖 (2023110917)
 * @notice 展示多层安全防护的投票机制
 */

contract SecureVoting {
    // 安全投票结构
    struct SecureProposal {
        bytes32 id;
        string description;
        address proposer;
        uint256 createdAt;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        ProposalState state;
        bool executed;
        bytes32 descriptionHash; // 防篡改
        mapping(address => Vote) votes;
        mapping(address => bool) hasVoted;
    }
    
    struct Vote {
        VoteChoice choice;
        uint256 timestamp;
        uint256 weight;
        bytes32 commitment; // 承诺投票
        bool revealed;
        bytes32 voteHash;
    }
    
    struct Voter {
        bool isRegistered;
        bool isActive;
        uint256 registrationTime;
        uint256 votingPower;
        uint256 lastVoteTime;
        uint256 totalVotes;
        bool isSuspended;
        string suspensionReason;
    }
    
    enum ProposalState { Pending, Active, Ended, Executed, Cancelled }
    enum VoteChoice { None, Yes, No, Abstain }
    
    // 安全状态变量
    mapping(bytes32 => SecureProposal) private proposals;
    mapping(address => Voter) private voters;
    mapping(address => mapping(bytes32 => bool)) private voterProposalAccess;
    
    bytes32[] private proposalIds;
    address private owner;
    address[] private admins;
    mapping(address => bool) private isAdmin;
    
    // 安全参数
    uint256 private constant MIN_VOTING_PERIOD = 1 hours;
    uint256 private constant MAX_VOTING_PERIOD = 30 days;
    uint256 private constant MIN_PROPOSAL_DELAY = 10 minutes;
    uint256 private constant MAX_DESCRIPTION_LENGTH = 1000;
    uint256 private constant VOTE_COOLDOWN = 5 minutes;
    uint256 private constant MAX_PROPOSALS_PER_DAY = 5;
    
    uint256 private minQuorum = 10;
    uint256 private passingThreshold = 51; // 51%
    bool private emergencyPause = false;
    bool private commitRevealVoting = true;
    
    // 安全统计
    mapping(address => uint256) private dailyProposalCount;
    mapping(address => uint256) private lastProposalDay;
    mapping(bytes32 => uint256) private proposalVoteCount;
    
    // 安全事件
    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, bytes32 descriptionHash);
    event VoteCommitted(bytes32 indexed proposalId, address indexed voter, bytes32 commitment);
    event VoteRevealed(bytes32 indexed proposalId, address indexed voter, VoteChoice choice, uint256 weight);
    event ProposalExecuted(bytes32 indexed proposalId, bool passed);
    event SecurityAlert(string alertType, address indexed account, bytes32 indexed proposalId);
    event VoterSuspended(address indexed voter, string reason);
    event EmergencyPause(bool paused);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    
    // 安全修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "SECURE: caller is not the owner");
        _;
    }
    
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner, "SECURE: caller is not an admin");
        _;
    }
    
    modifier whenNotPaused() {
        require(!emergencyPause, "SECURE: voting is paused");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "SECURE: voter not registered");
        require(voters[msg.sender].isActive, "SECURE: voter not active");
        require(!voters[msg.sender].isSuspended, "SECURE: voter is suspended");
        _;
    }
    
    modifier validProposal(bytes32 proposalId) {
        require(proposals[proposalId].createdAt > 0, "SECURE: proposal does not exist");
        _;
    }
    
    modifier proposalRateLimit() {
        uint256 today = block.timestamp / 1 days;
        if (lastProposalDay[msg.sender] < today) {
            dailyProposalCount[msg.sender] = 0;
            lastProposalDay[msg.sender] = today;
        }
        require(
            dailyProposalCount[msg.sender] < MAX_PROPOSALS_PER_DAY,
            "SECURE: daily proposal limit exceeded"
        );
        dailyProposalCount[msg.sender]++;
        _;
    }
    
    modifier voteCooldown() {
        require(
            block.timestamp >= voters[msg.sender].lastVoteTime + VOTE_COOLDOWN,
            "SECURE: vote cooldown not met"
        );
        _;
    }
    
    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        admins.push(msg.sender);
        
        // 注册owner为投票者
        voters[msg.sender] = Voter({
            isRegistered: true,
            isActive: true,
            registrationTime: block.timestamp,
            votingPower: 1,
            lastVoteTime: 0,
            totalVotes: 0,
            isSuspended: false,
            suspensionReason: ""
        });
    }
    
    /**
     * @dev 安全的投票者注册
     */
    function registerVoter(address voter, uint256 votingPower) 
        public 
        onlyAdmin 
        whenNotPaused 
    {
        require(voter != address(0), "SECURE: invalid voter address");
        require(!voters[voter].isRegistered, "SECURE: voter already registered");
        require(votingPower > 0 && votingPower <= 10, "SECURE: invalid voting power");
        
        voters[voter] = Voter({
            isRegistered: true,
            isActive: true,
            registrationTime: block.timestamp,
            votingPower: votingPower,
            lastVoteTime: 0,
            totalVotes: 0,
            isSuspended: false,
            suspensionReason: ""
        });
        
        emit SecurityAlert("Voter Registered", voter, bytes32(0));
    }
    
    /**
     * @dev 安全的提案创建
     */
    function createProposal(
        string memory description,
        uint256 votingDuration
    ) 
        public 
        onlyRegisteredVoter 
        whenNotPaused 
        proposalRateLimit
        returns (bytes32) 
    {
        require(bytes(description).length > 0, "SECURE: empty description");
        require(bytes(description).length <= MAX_DESCRIPTION_LENGTH, "SECURE: description too long");
        require(votingDuration >= MIN_VOTING_PERIOD, "SECURE: voting period too short");
        require(votingDuration <= MAX_VOTING_PERIOD, "SECURE: voting period too long");
        
        // 生成安全的提案ID
        bytes32 proposalId = keccak256(
            abi.encodePacked(
                description,
                msg.sender,
                block.timestamp,
                block.difficulty,
                proposalIds.length
            )
        );
        
        // 防止重复提案
        require(proposals[proposalId].createdAt == 0, "SECURE: duplicate proposal");
        
        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 votingStart = block.timestamp + MIN_PROPOSAL_DELAY;
        uint256 votingEnd = votingStart + votingDuration;
        
        SecureProposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.votingStart = votingStart;
        proposal.votingEnd = votingEnd;
        proposal.state = ProposalState.Pending;
        proposal.descriptionHash = descriptionHash;
        
        proposalIds.push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, descriptionHash);
        return proposalId;
    }
    
    /**
     * @dev 承诺投票（第一阶段）
     */
    function commitVote(bytes32 proposalId, bytes32 commitment) 
        public 
        onlyRegisteredVoter 
        whenNotPaused 
        validProposal(proposalId) 
        voteCooldown
    {
        SecureProposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.votingStart, "SECURE: voting not started");
        require(block.timestamp <= proposal.votingEnd, "SECURE: voting ended");
        require(proposal.state == ProposalState.Active || proposal.state == ProposalState.Pending, "SECURE: invalid proposal state");
        require(!proposal.hasVoted[msg.sender], "SECURE: already voted");
        require(commitment != bytes32(0), "SECURE: invalid commitment");
        
        // 激活提案
        if (proposal.state == ProposalState.Pending) {
            proposal.state = ProposalState.Active;
        }
        
        // 记录承诺
        proposal.votes[msg.sender] = Vote({
            choice: VoteChoice.None,
            timestamp: block.timestamp,
            weight: voters[msg.sender].votingPower,
            commitment: commitment,
            revealed: false,
            voteHash: bytes32(0)
        });
        
        proposal.hasVoted[msg.sender] = true;
        voters[msg.sender].lastVoteTime = block.timestamp;
        proposalVoteCount[proposalId]++;
        
        emit VoteCommitted(proposalId, msg.sender, commitment);
    }
    
    /**
     * @dev 揭示投票（第二阶段）
     */
    function revealVote(
        bytes32 proposalId, 
        VoteChoice choice, 
        uint256 nonce
    ) 
        public 
        onlyRegisteredVoter 
        whenNotPaused 
        validProposal(proposalId) 
    {
        SecureProposal storage proposal = proposals[proposalId];
        Vote storage vote = proposal.votes[msg.sender];
        
        require(proposal.hasVoted[msg.sender], "SECURE: no commitment found");
        require(!vote.revealed, "SECURE: vote already revealed");
        require(choice != VoteChoice.None, "SECURE: invalid vote choice");
        
        // 验证承诺
        bytes32 expectedCommitment = keccak256(abi.encodePacked(choice, nonce, msg.sender));
        require(vote.commitment == expectedCommitment, "SECURE: invalid reveal");
        
        // 记录投票
        vote.choice = choice;
        vote.revealed = true;
        vote.voteHash = keccak256(abi.encodePacked(choice, msg.sender, block.timestamp));
        
        // 更新投票统计
        if (choice == VoteChoice.Yes) {
            proposal.yesVotes += vote.weight;
        } else if (choice == VoteChoice.No) {
            proposal.noVotes += vote.weight;
        } else if (choice == VoteChoice.Abstain) {
            proposal.abstainVotes += vote.weight;
        }
        
        voters[msg.sender].totalVotes++;
        
        emit VoteRevealed(proposalId, msg.sender, choice, vote.weight);
        
        // 检查异常投票模式
        _checkSuspiciousVoting(msg.sender, proposalId);
    }
    
    /**
     * @dev 直接投票（如果禁用承诺-揭示）
     */
    function directVote(bytes32 proposalId, VoteChoice choice) 
        public 
        onlyRegisteredVoter 
        whenNotPaused 
        validProposal(proposalId) 
        voteCooldown
    {
        require(!commitRevealVoting, "SECURE: direct voting disabled");
        
        SecureProposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.votingStart, "SECURE: voting not started");
        require(block.timestamp <= proposal.votingEnd, "SECURE: voting ended");
        require(proposal.state == ProposalState.Active || proposal.state == ProposalState.Pending, "SECURE: invalid proposal state");
        require(!proposal.hasVoted[msg.sender], "SECURE: already voted");
        require(choice != VoteChoice.None, "SECURE: invalid vote choice");
        
        // 激活提案
        if (proposal.state == ProposalState.Pending) {
            proposal.state = ProposalState.Active;
        }
        
        uint256 weight = voters[msg.sender].votingPower;
        
        // 记录投票
        proposal.votes[msg.sender] = Vote({
            choice: choice,
            timestamp: block.timestamp,
            weight: weight,
            commitment: bytes32(0),
            revealed: true,
            voteHash: keccak256(abi.encodePacked(choice, msg.sender, block.timestamp))
        });
        
        proposal.hasVoted[msg.sender] = true;
        
        // 更新投票统计
        if (choice == VoteChoice.Yes) {
            proposal.yesVotes += weight;
        } else if (choice == VoteChoice.No) {
            proposal.noVotes += weight;
        } else if (choice == VoteChoice.Abstain) {
            proposal.abstainVotes += weight;
        }
        
        voters[msg.sender].lastVoteTime = block.timestamp;
        voters[msg.sender].totalVotes++;
        proposalVoteCount[proposalId]++;
        
        emit VoteRevealed(proposalId, msg.sender, choice, weight);
        
        // 检查异常投票模式
        _checkSuspiciousVoting(msg.sender, proposalId);
    }
    
    /**
     * @dev 检查可疑投票行为
     */
    function _checkSuspiciousVoting(address voter, bytes32 proposalId) private {
        // 检查投票频率
        if (voters[voter].totalVotes > 0 && 
            block.timestamp - voters[voter].lastVoteTime < VOTE_COOLDOWN * 2) {
            emit SecurityAlert("Rapid Voting", voter, proposalId);
        }
        
        // 检查投票模式
        if (voters[voter].totalVotes > 10) {
            // 这里可以添加更复杂的模式检测逻辑
            emit SecurityAlert("High Vote Count", voter, proposalId);
        }
    }
    
    /**
     * @dev 执行提案
     */
    function executeProposal(bytes32 proposalId) 
        public 
        onlyAdmin 
        validProposal(proposalId) 
        returns (bool) 
    {
        SecureProposal storage proposal = proposals[proposalId];
        
        require(block.timestamp > proposal.votingEnd, "SECURE: voting still active");
        require(proposal.state == ProposalState.Active, "SECURE: proposal not active");
        require(!proposal.executed, "SECURE: proposal already executed");
        
        // 检查法定人数
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
        require(totalVotes >= minQuorum, "SECURE: quorum not met");
        
        // 计算结果
        uint256 validVotes = proposal.yesVotes + proposal.noVotes;
        bool passed = (proposal.yesVotes * 100) / validVotes >= passingThreshold;
        
        proposal.executed = true;
        proposal.state = ProposalState.Executed;
        
        emit ProposalExecuted(proposalId, passed);
        return passed;
    }
    
    /**
     * @dev 暂停投票者
     */
    function suspendVoter(address voter, string memory reason) public onlyAdmin {
        require(voters[voter].isRegistered, "SECURE: voter not registered");
        require(!voters[voter].isSuspended, "SECURE: voter already suspended");
        
        voters[voter].isSuspended = true;
        voters[voter].suspensionReason = reason;
        
        emit VoterSuspended(voter, reason);
        emit SecurityAlert("Voter Suspended", voter, bytes32(0));
    }
    
    /**
     * @dev 恢复投票者
     */
    function unsuspendVoter(address voter) public onlyAdmin {
        require(voters[voter].isSuspended, "SECURE: voter not suspended");
        
        voters[voter].isSuspended = false;
        voters[voter].suspensionReason = "";
        
        emit SecurityAlert("Voter Unsuspended", voter, bytes32(0));
    }
    
    /**
     * @dev 紧急暂停
     */
    function emergencyPauseVoting() public onlyAdmin {
        emergencyPause = true;
        emit EmergencyPause(true);
        emit SecurityAlert("Emergency Pause Activated", msg.sender, bytes32(0));
    }
    
    /**
     * @dev 恢复投票
     */
    function resumeVoting() public onlyAdmin {
        emergencyPause = false;
        emit EmergencyPause(false);
        emit SecurityAlert("Emergency Pause Deactivated", msg.sender, bytes32(0));
    }
    
    /**
     * @dev 添加管理员
     */
    function addAdmin(address admin) public onlyOwner {
        require(admin != address(0), "SECURE: invalid admin address");
        require(!isAdmin[admin], "SECURE: already an admin");
        
        isAdmin[admin] = true;
        admins.push(admin);
        
        emit AdminAdded(admin);
    }
    
    /**
     * @dev 移除管理员
     */
    function removeAdmin(address admin) public onlyOwner {
        require(isAdmin[admin], "SECURE: not an admin");
        require(admin != owner, "SECURE: cannot remove owner");
        
        isAdmin[admin] = false;
        
        // 从数组中移除
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
        
        emit AdminRemoved(admin);
    }
    
    /**
     * @dev 获取提案信息
     */
    function getProposal(bytes32 proposalId) 
        public 
        view 
        validProposal(proposalId) 
        returns (
            string memory description,
            address proposer,
            uint256 votingStart,
            uint256 votingEnd,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 abstainVotes,
            ProposalState state,
            bool executed
        ) 
    {
        SecureProposal storage proposal = proposals[proposalId];
        return (
            proposal.description,
            proposal.proposer,
            proposal.votingStart,
            proposal.votingEnd,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.abstainVotes,
            proposal.state,
            proposal.executed
        );
    }
    
    /**
     * @dev 获取投票者信息
     */
    function getVoterInfo(address voter) 
        public 
        view 
        returns (
            bool isRegistered,
            bool isActive,
            uint256 votingPower,
            uint256 totalVotes,
            bool isSuspended,
            string memory suspensionReason
        ) 
    {
        Voter storage v = voters[voter];
        return (
            v.isRegistered,
            v.isActive,
            v.votingPower,
            v.totalVotes,
            v.isSuspended,
            v.suspensionReason
        );
    }
    
    /**
     * @dev 获取系统安全状态
     */
    function getSecurityStatus() 
        public 
        view 
        returns (
            bool isPaused,
            bool commitRevealEnabled,
            uint256 minQuorum_,
            uint256 passingThreshold_,
            uint256 totalProposals
        ) 
    {
        return (
            emergencyPause,
            commitRevealVoting,
            minQuorum,
            passingThreshold,
            proposalIds.length
        );
    }
    
    function getAllProposalIds() public view returns (bytes32[] memory) {
        return proposalIds;
    }
    
    function getAdmins() public view returns (address[] memory) {
        return admins;
    }
}

/*
安全导向投票系统特色：

1. 多重身份验证
   - 投票者注册机制
   - 管理员权限控制
   - 暂停/恢复功能
   - 身份状态追踪

2. 投票安全机制
   - 承诺-揭示投票
   - 投票冷却时间
   - 提案频率限制
   - 重复投票防护

3. 异常检测系统
   - 可疑投票模式检测
   - 频率异常监控
   - 安全事件记录
   - 自动报警机制

4. 紧急响应机制
   - 紧急暂停功能
   - 投票者暂停机制
   - 管理员权限管理
   - 状态恢复功能

5. 数据完整性保护
   - 描述哈希验证
   - 投票承诺验证
   - 状态一致性检查
   - 防篡改机制

这种设计体现了安全优先的治理理念：
身份验证、异常检测、紧急响应、数据完整性。
*/