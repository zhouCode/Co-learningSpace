// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VotingSystem - 实用主义的投票系统
 * @author 唐秋平 (2023110659)
 * @notice 注重实际应用和用户体验的去中心化投票系统
 * @dev 以解决实际治理需求为导向的投票合约设计
 * 学习日期: 2024年10月16日
 */

/**
 * @title VotingSystem - 实用主义投票系统
 * @dev 专注于实际治理场景的投票系统实现
 * 特点：
 * 1. 简单易用的投票流程
 * 2. 灵活的提案管理
 * 3. 实用的权限控制
 * 4. 用户友好的查询功能
 */
contract VotingSystem {
    // ============ 结构体定义 ============
    
    /**
     * @dev 提案结构体 - 实用设计：包含所有必要信息
     */
    struct Proposal {
        uint256 id;                    // 提案ID
        string title;                  // 提案标题
        string description;            // 提案描述
        address proposer;              // 提案人
        uint256 startTime;             // 投票开始时间
        uint256 endTime;               // 投票结束时间
        uint256 yesVotes;              // 赞成票数
        uint256 noVotes;               // 反对票数
        uint256 abstainVotes;          // 弃权票数
        bool executed;                 // 是否已执行
        bool cancelled;                // 是否已取消
        ProposalType proposalType;     // 提案类型
        uint256 requiredQuorum;        // 所需法定人数
        uint256 requiredMajority;      // 所需多数比例（基点）
        bytes executionData;           // 执行数据
        address targetContract;        // 目标合约地址
    }
    
    /**
     * @dev 投票记录结构体
     */
    struct Vote {
        bool hasVoted;                 // 是否已投票
        VoteChoice choice;             // 投票选择
        uint256 weight;                // 投票权重
        uint256 timestamp;             // 投票时间
        string reason;                 // 投票理由（可选）
    }
    
    /**
     * @dev 投票者信息结构体 - 实用功能：权重管理
     */
    struct Voter {
        bool isEligible;               // 是否有投票资格
        uint256 weight;                // 投票权重
        uint256 reputation;            // 声誉值
        uint256 joinTime;              // 加入时间
        bool isDelegate;               // 是否为代理人
        address delegatedTo;           // 委托给谁
        uint256 delegatedWeight;       // 被委托的权重
    }
    
    // ============ 枚举定义 ============
    
    enum ProposalType {
        GENERAL,                       // 一般提案
        CONSTITUTIONAL,                // 宪法修改
        BUDGET,                        // 预算提案
        TECHNICAL,                     // 技术升级
        EMERGENCY                      // 紧急提案
    }
    
    enum VoteChoice {
        YES,                          // 赞成
        NO,                           // 反对
        ABSTAIN                       // 弃权
    }
    
    enum ProposalStatus {
        PENDING,                      // 待开始
        ACTIVE,                       // 进行中
        SUCCEEDED,                    // 通过
        FAILED,                       // 失败
        EXECUTED,                     // 已执行
        CANCELLED                     // 已取消
    }
    
    // ============ 状态变量 ============
    
    // 基础管理
    address public admin;
    string public organizationName;
    bool public isPaused;
    
    // 提案管理
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256[]) public userProposals; // 用户创建的提案
    
    // 投票管理
    mapping(uint256 => mapping(address => Vote)) public votes; // 提案ID => 用户地址 => 投票
    mapping(address => Voter) public voters;
    
    // 实用功能：投票统计
    mapping(uint256 => address[]) public proposalVoters; // 提案的投票者列表
    mapping(address => uint256[]) public userVotes; // 用户参与的投票
    
    // 实用功能：委托投票
    mapping(address => address[]) public delegators; // 委托人列表
    mapping(address => uint256) public totalDelegatedWeight; // 总委托权重
    
    // 配置参数 - 实用设计：可调整的治理参数
    uint256 public minProposalDuration = 3 days;      // 最短投票时间
    uint256 public maxProposalDuration = 30 days;     // 最长投票时间
    uint256 public defaultQuorum = 1000;              // 默认法定人数（基点，10%）
    uint256 public defaultMajority = 5000;            // 默认多数要求（基点，50%）
    uint256 public proposalDeposit = 0.1 ether;       // 提案押金
    uint256 public minVotingWeight = 1;               // 最小投票权重
    
    // 实用功能：提案类型配置
    mapping(ProposalType => uint256) public typeQuorum;     // 各类型法定人数
    mapping(ProposalType => uint256) public typeMajority;   // 各类型多数要求
    mapping(ProposalType => uint256) public typeDeposit;    // 各类型押金
    
    // 统计数据 - 实用功能：数据分析
    uint256 public totalVoters;
    uint256 public totalVotingWeight;
    uint256 public activeProposals;
    
    // ============ 事件定义 ============
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice choice,
        uint256 weight,
        string reason
    );
    
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event ProposalCancelled(uint256 indexed proposalId, address indexed canceller);
    
    event VoterRegistered(address indexed voter, uint256 weight);
    event VoterWeightUpdated(address indexed voter, uint256 oldWeight, uint256 newWeight);
    
    event VoteDelegated(address indexed delegator, address indexed delegate, uint256 weight);
    event VoteDelegationRevoked(address indexed delegator, address indexed delegate);
    
    event QuorumUpdated(ProposalType proposalType, uint256 oldQuorum, uint256 newQuorum);
    event MajorityUpdated(ProposalType proposalType, uint256 oldMajority, uint256 newMajority);
    
    event SystemPaused(address indexed admin);
    event SystemUnpaused(address indexed admin);
    
    // 实用功能：批量操作事件
    event BatchVoterRegistration(uint256 voterCount);
    event BatchProposalUpdate(uint256[] proposalIds);
    
    // ============ 修饰符 ============
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier whenNotPaused() {
        require(!isPaused, "System is paused");
        _;
    }
    
    modifier onlyEligibleVoter() {
        require(voters[msg.sender].isEligible, "Not eligible to vote");
        _;
    }
    
    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }
    
    modifier proposalActive(uint256 proposalId) {
        require(getProposalStatus(proposalId) == ProposalStatus.ACTIVE, "Proposal not active");
        _;
    }
    
    modifier hasNotVoted(uint256 proposalId) {
        require(!votes[proposalId][msg.sender].hasVoted, "Already voted on this proposal");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数 - 实用主义：提供灵活的初始化
     * @param _organizationName 组织名称
     * @param _initialVoters 初始投票者地址数组
     * @param _initialWeights 初始投票者权重数组
     */
    constructor(
        string memory _organizationName,
        address[] memory _initialVoters,
        uint256[] memory _initialWeights
    ) payable {
        require(bytes(_organizationName).length > 0, "Organization name cannot be empty");
        require(_initialVoters.length == _initialWeights.length, "Arrays length mismatch");
        
        admin = msg.sender;
        organizationName = _organizationName;
        
        // 初始化提案类型配置 - 实用设置：不同类型不同要求
        _initializeProposalTypeConfigs();
        
        // 注册初始投票者
        for (uint256 i = 0; i < _initialVoters.length; i++) {
            if (_initialVoters[i] != address(0) && _initialWeights[i] > 0) {
                _registerVoter(_initialVoters[i], _initialWeights[i]);
            }
        }
        
        // 管理员自动注册为投票者
        if (!voters[admin].isEligible) {
            _registerVoter(admin, 100); // 管理员默认权重100
        }
    }
    
    // ============ 提案管理功能 ============
    
    /**
     * @dev 创建提案 - 实用功能：支持多种提案类型
     * @param title 提案标题
     * @param description 提案描述
     * @param duration 投票持续时间（秒）
     * @param proposalType 提案类型
     * @param targetContract 目标合约地址（如果需要执行）
     * @param executionData 执行数据
     * @return proposalId 提案ID
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 duration,
        ProposalType proposalType,
        address targetContract,
        bytes memory executionData
    ) public payable whenNotPaused onlyEligibleVoter returns (uint256 proposalId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(duration >= minProposalDuration && duration <= maxProposalDuration, "Invalid duration");
        
        // 检查押金
        uint256 requiredDeposit = typeDeposit[proposalType] > 0 ? typeDeposit[proposalType] : proposalDeposit;
        require(msg.value >= requiredDeposit, "Insufficient deposit");
        
        proposalCount++;
        proposalId = proposalCount;
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            yesVotes: 0,
            noVotes: 0,
            abstainVotes: 0,
            executed: false,
            cancelled: false,
            proposalType: proposalType,
            requiredQuorum: typeQuorum[proposalType] > 0 ? typeQuorum[proposalType] : defaultQuorum,
            requiredMajority: typeMajority[proposalType] > 0 ? typeMajority[proposalType] : defaultMajority,
            executionData: executionData,
            targetContract: targetContract
        });
        
        userProposals[msg.sender].push(proposalId);
        activeProposals++;
        
        emit ProposalCreated(proposalId, msg.sender, title, proposalType, startTime, endTime);
        
        // 退还多余的押金
        if (msg.value > requiredDeposit) {
            payable(msg.sender).transfer(msg.value - requiredDeposit);
        }
    }
    
    /**
     * @dev 快速创建简单提案 - 实用功能：简化操作
     * @param title 提案标题
     * @param description 提案描述
     * @return proposalId 提案ID
     */
    function createSimpleProposal(
        string memory title,
        string memory description
    ) public payable whenNotPaused onlyEligibleVoter returns (uint256 proposalId) {
        return createProposal(
            title,
            description,
            7 days, // 默认7天投票期
            ProposalType.GENERAL,
            address(0),
            ""
        );
    }
    
    /**
     * @dev 取消提案 - 实用功能：提案管理
     * @param proposalId 提案ID
     */
    function cancelProposal(uint256 proposalId) public whenNotPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "Only proposer or admin can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.cancelled, "Proposal already cancelled");
        
        proposal.cancelled = true;
        if (getProposalStatus(proposalId) == ProposalStatus.ACTIVE) {
            activeProposals--;
        }
        
        emit ProposalCancelled(proposalId, msg.sender);
        
        // 退还押金给提案人
        uint256 deposit = typeDeposit[proposal.proposalType] > 0 ? 
                         typeDeposit[proposal.proposalType] : proposalDeposit;
        if (deposit > 0 && address(this).balance >= deposit) {
            payable(proposal.proposer).transfer(deposit);
        }
    }
    
    // ============ 投票功能 ============
    
    /**
     * @dev 投票 - 核心功能：支持权重投票和理由说明
     * @param proposalId 提案ID
     * @param choice 投票选择
     * @param reason 投票理由（可选）
     */
    function vote(
        uint256 proposalId,
        VoteChoice choice,
        string memory reason
    ) public whenNotPaused validProposal(proposalId) proposalActive(proposalId) onlyEligibleVoter hasNotVoted(proposalId) {
        Voter storage voter = voters[msg.sender];
        uint256 votingWeight = voter.weight + voter.delegatedWeight;
        
        require(votingWeight >= minVotingWeight, "Insufficient voting weight");
        
        // 记录投票
        votes[proposalId][msg.sender] = Vote({
            hasVoted: true,
            choice: choice,
            weight: votingWeight,
            timestamp: block.timestamp,
            reason: reason
        });
        
        // 更新提案投票统计
        Proposal storage proposal = proposals[proposalId];
        if (choice == VoteChoice.YES) {
            proposal.yesVotes += votingWeight;
        } else if (choice == VoteChoice.NO) {
            proposal.noVotes += votingWeight;
        } else {
            proposal.abstainVotes += votingWeight;
        }
        
        // 记录投票者
        proposalVoters[proposalId].push(msg.sender);
        userVotes[msg.sender].push(proposalId);
        
        emit VoteCast(proposalId, msg.sender, choice, votingWeight, reason);
    }
    
    /**
     * @dev 批量投票 - 实用功能：提高效率
     * @param proposalIds 提案ID数组
     * @param choices 投票选择数组
     * @param reasons 投票理由数组
     */
    function batchVote(
        uint256[] memory proposalIds,
        VoteChoice[] memory choices,
        string[] memory reasons
    ) public whenNotPaused onlyEligibleVoter {
        require(proposalIds.length == choices.length, "Arrays length mismatch");
        require(proposalIds.length == reasons.length, "Arrays length mismatch");
        require(proposalIds.length <= 10, "Too many proposals"); // 实用限制
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (getProposalStatus(proposalIds[i]) == ProposalStatus.ACTIVE && 
                !votes[proposalIds[i]][msg.sender].hasVoted) {
                vote(proposalIds[i], choices[i], reasons[i]);
            }
        }
    }
    
    /**
     * @dev 委托投票 - 实用功能：代理投票
     * @param delegate 代理人地址
     */
    function delegateVote(address delegate) public whenNotPaused onlyEligibleVoter {
        require(delegate != address(0), "Invalid delegate address");
        require(delegate != msg.sender, "Cannot delegate to yourself");
        require(voters[delegate].isEligible, "Delegate not eligible");
        require(voters[msg.sender].delegatedTo == address(0), "Already delegated");
        
        Voter storage delegator = voters[msg.sender];
        Voter storage delegateVoter = voters[delegate];
        
        // 更新委托关系
        delegator.delegatedTo = delegate;
        delegateVoter.delegatedWeight += delegator.weight;
        totalDelegatedWeight[delegate] += delegator.weight;
        
        // 记录委托关系
        delegators[delegate].push(msg.sender);
        
        emit VoteDelegated(msg.sender, delegate, delegator.weight);
    }
    
    /**
     * @dev 撤销委托 - 实用功能：灵活管理
     */
    function revokeDelegation() public whenNotPaused onlyEligibleVoter {
        address delegate = voters[msg.sender].delegatedTo;
        require(delegate != address(0), "No active delegation");
        
        Voter storage delegator = voters[msg.sender];
        Voter storage delegateVoter = voters[delegate];
        
        // 更新委托关系
        uint256 weight = delegator.weight;
        delegator.delegatedTo = address(0);
        delegateVoter.delegatedWeight -= weight;
        totalDelegatedWeight[delegate] -= weight;
        
        // 从委托人列表中移除
        address[] storage delegatorList = delegators[delegate];
        for (uint256 i = 0; i < delegatorList.length; i++) {
            if (delegatorList[i] == msg.sender) {
                delegatorList[i] = delegatorList[delegatorList.length - 1];
                delegatorList.pop();
                break;
            }
        }
        
        emit VoteDelegationRevoked(msg.sender, delegate);
    }
    
    // ============ 提案执行功能 ============
    
    /**
     * @dev 执行提案 - 实用功能：自动执行通过的提案
     * @param proposalId 提案ID
     */
    function executeProposal(uint256 proposalId) public whenNotPaused validProposal(proposalId) {
        require(getProposalStatus(proposalId) == ProposalStatus.SUCCEEDED, "Proposal not succeeded");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        
        proposal.executed = true;
        activeProposals--;
        
        bool success = true;
        
        // 执行提案（如果有执行数据）
        if (proposal.targetContract != address(0) && proposal.executionData.length > 0) {
            (success,) = proposal.targetContract.call(proposal.executionData);
        }
        
        emit ProposalExecuted(proposalId, success);
        
        // 如果执行成功，退还押金；否则没收押金
        if (success) {
            uint256 deposit = typeDeposit[proposal.proposalType] > 0 ? 
                             typeDeposit[proposal.proposalType] : proposalDeposit;
            if (deposit > 0 && address(this).balance >= deposit) {
                payable(proposal.proposer).transfer(deposit);
            }
        }
    }
    
    /**
     * @dev 批量执行提案 - 实用功能：批量处理
     * @param proposalIds 提案ID数组
     */
    function batchExecuteProposals(uint256[] memory proposalIds) public whenNotPaused {
        require(proposalIds.length <= 10, "Too many proposals");
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (getProposalStatus(proposalIds[i]) == ProposalStatus.SUCCEEDED) {
                executeProposal(proposalIds[i]);
            }
        }
        
        emit BatchProposalUpdate(proposalIds);
    }
    
    // ============ 投票者管理功能 ============
    
    /**
     * @dev 注册投票者 - 管理功能
     * @param voter 投票者地址
     * @param weight 投票权重
     */
    function registerVoter(address voter, uint256 weight) public onlyAdmin {
        _registerVoter(voter, weight);
    }
    
    /**
     * @dev 批量注册投票者 - 实用功能：批量管理
     * @param voterAddresses 投票者地址数组
     * @param weights 权重数组
     */
    function batchRegisterVoters(
        address[] memory voterAddresses,
        uint256[] memory weights
    ) public onlyAdmin {
        require(voterAddresses.length == weights.length, "Arrays length mismatch");
        require(voterAddresses.length <= 50, "Too many voters"); // 实用限制
        
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            if (voterAddresses[i] != address(0) && weights[i] > 0) {
                _registerVoter(voterAddresses[i], weights[i]);
            }
        }
        
        emit BatchVoterRegistration(voterAddresses.length);
    }
    
    /**
     * @dev 更新投票者权重
     * @param voter 投票者地址
     * @param newWeight 新权重
     */
    function updateVoterWeight(address voter, uint256 newWeight) public onlyAdmin {
        require(voters[voter].isEligible, "Voter not registered");
        require(newWeight > 0, "Weight must be positive");
        
        uint256 oldWeight = voters[voter].weight;
        voters[voter].weight = newWeight;
        
        // 更新总权重
        totalVotingWeight = totalVotingWeight - oldWeight + newWeight;
        
        // 如果有委托关系，更新委托权重
        address delegate = voters[voter].delegatedTo;
        if (delegate != address(0)) {
            voters[delegate].delegatedWeight = voters[delegate].delegatedWeight - oldWeight + newWeight;
            totalDelegatedWeight[delegate] = totalDelegatedWeight[delegate] - oldWeight + newWeight;
        }
        
        emit VoterWeightUpdated(voter, oldWeight, newWeight);
    }
    
    /**
     * @dev 移除投票者资格
     * @param voter 投票者地址
     */
    function removeVoter(address voter) public onlyAdmin {
        require(voters[voter].isEligible, "Voter not registered");
        require(voter != admin, "Cannot remove admin");
        
        Voter storage voterData = voters[voter];
        
        // 撤销所有委托关系
        if (voterData.delegatedTo != address(0)) {
            // 如果该投票者委托了别人，撤销委托
            address delegate = voterData.delegatedTo;
            voters[delegate].delegatedWeight -= voterData.weight;
            totalDelegatedWeight[delegate] -= voterData.weight;
        }
        
        // 如果有人委托给该投票者，撤销所有委托
        address[] storage delegatorList = delegators[voter];
        for (uint256 i = 0; i < delegatorList.length; i++) {
            voters[delegatorList[i]].delegatedTo = address(0);
        }
        delete delegators[voter];
        
        // 更新统计
        totalVotingWeight -= voterData.weight;
        totalVoters--;
        
        // 移除投票者
        delete voters[voter];
    }
    
    // ============ 查询功能 ============
    
    /**
     * @dev 获取提案状态 - 实用功能：状态查询
     * @param proposalId 提案ID
     * @return 提案状态
     */
    function getProposalStatus(uint256 proposalId) public view validProposal(proposalId) returns (ProposalStatus) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.cancelled) {
            return ProposalStatus.CANCELLED;
        }
        
        if (proposal.executed) {
            return ProposalStatus.EXECUTED;
        }
        
        if (block.timestamp < proposal.startTime) {
            return ProposalStatus.PENDING;
        }
        
        if (block.timestamp <= proposal.endTime) {
            return ProposalStatus.ACTIVE;
        }
        
        // 检查是否通过
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (totalVotingWeight * proposal.requiredQuorum) / 10000;
        
        if (totalVotes < requiredQuorum) {
            return ProposalStatus.FAILED;
        }
        
        uint256 requiredMajority = (totalVotes * proposal.requiredMajority) / 10000;
        if (proposal.yesVotes >= requiredMajority) {
            return ProposalStatus.SUCCEEDED;
        }
        
        return ProposalStatus.FAILED;
    }
    
    /**
     * @dev 获取提案详细信息 - 实用功能：完整信息查询
     * @param proposalId 提案ID
     * @return 提案信息和统计数据
     */
    function getProposalDetails(uint256 proposalId) public view validProposal(proposalId) returns (
        Proposal memory proposal,
        ProposalStatus status,
        uint256 totalVotes,
        uint256 participationRate,
        bool canExecute
    ) {
        proposal = proposals[proposalId];
        status = getProposalStatus(proposalId);
        totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
        participationRate = totalVotingWeight > 0 ? (totalVotes * 10000) / totalVotingWeight : 0;
        canExecute = (status == ProposalStatus.SUCCEEDED && !proposal.executed);
    }
    
    /**
     * @dev 获取用户投票信息 - 实用功能：个人数据查询
     * @param user 用户地址
     * @param proposalId 提案ID
     * @return 投票信息
     */
    function getUserVote(address user, uint256 proposalId) public view validProposal(proposalId) returns (
        bool hasVoted,
        VoteChoice choice,
        uint256 weight,
        uint256 timestamp,
        string memory reason
    ) {
        Vote storage userVote = votes[proposalId][user];
        return (
            userVote.hasVoted,
            userVote.choice,
            userVote.weight,
            userVote.timestamp,
            userVote.reason
        );
    }
    
    /**
     * @dev 获取用户统计信息 - 实用功能：用户画像
     * @param user 用户地址
     * @return 用户统计数据
     */
    function getUserStats(address user) public view returns (
        bool isEligible,
        uint256 weight,
        uint256 totalWeight,
        uint256 proposalsCreated,
        uint256 votesParticipated,
        address delegatedTo,
        uint256 delegatorsCount
    ) {
        Voter storage voter = voters[user];
        return (
            voter.isEligible,
            voter.weight,
            voter.weight + voter.delegatedWeight,
            userProposals[user].length,
            userVotes[user].length,
            voter.delegatedTo,
            delegators[user].length
        );
    }
    
    /**
     * @dev 获取活跃提案列表 - 实用功能：列表查询
     * @return 活跃提案ID数组
     */
    function getActiveProposals() public view returns (uint256[] memory) {
        uint256[] memory activeList = new uint256[](activeProposals);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (getProposalStatus(i) == ProposalStatus.ACTIVE) {
                activeList[index] = i;
                index++;
            }
        }
        
        return activeList;
    }
    
    /**
     * @dev 获取系统统计信息 - 实用功能：系统概览
     * @return 系统统计数据
     */
    function getSystemStats() public view returns (
        uint256 totalProposals,
        uint256 activeProposalsCount,
        uint256 totalVotersCount,
        uint256 totalWeight,
        uint256 avgParticipationRate
    ) {
        // 计算平均参与率
        uint256 totalParticipation = 0;
        uint256 completedProposals = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            ProposalStatus status = getProposalStatus(i);
            if (status == ProposalStatus.SUCCEEDED || status == ProposalStatus.FAILED || status == ProposalStatus.EXECUTED) {
                Proposal storage proposal = proposals[i];
                uint256 totalVotes = proposal.yesVotes + proposal.noVotes + proposal.abstainVotes;
                if (totalVotingWeight > 0) {
                    totalParticipation += (totalVotes * 10000) / totalVotingWeight;
                    completedProposals++;
                }
            }
        }
        
        uint256 avgParticipation = completedProposals > 0 ? totalParticipation / completedProposals : 0;
        
        return (
            proposalCount,
            activeProposals,
            totalVoters,
            totalVotingWeight,
            avgParticipation
        );
    }
    
    // ============ 配置管理功能 ============
    
    /**
     * @dev 更新提案类型配置 - 管理功能
     * @param proposalType 提案类型
     * @param quorum 法定人数（基点）
     * @param majority 多数要求（基点）
     * @param deposit 押金要求
     */
    function updateProposalTypeConfig(
        ProposalType proposalType,
        uint256 quorum,
        uint256 majority,
        uint256 deposit
    ) public onlyAdmin {
        require(quorum <= 10000, "Quorum cannot exceed 100%");
        require(majority <= 10000, "Majority cannot exceed 100%");
        
        uint256 oldQuorum = typeQuorum[proposalType];
        uint256 oldMajority = typeMajority[proposalType];
        
        typeQuorum[proposalType] = quorum;
        typeMajority[proposalType] = majority;
        typeDeposit[proposalType] = deposit;
        
        emit QuorumUpdated(proposalType, oldQuorum, quorum);
        emit MajorityUpdated(proposalType, oldMajority, majority);
    }
    
    /**
     * @dev 更新系统参数
     * @param _minDuration 最短投票时间
     * @param _maxDuration 最长投票时间
     * @param _defaultQuorum 默认法定人数
     * @param _defaultMajority 默认多数要求
     * @param _proposalDeposit 提案押金
     */
    function updateSystemParams(
        uint256 _minDuration,
        uint256 _maxDuration,
        uint256 _defaultQuorum,
        uint256 _defaultMajority,
        uint256 _proposalDeposit
    ) public onlyAdmin {
        require(_minDuration > 0 && _maxDuration > _minDuration, "Invalid duration range");
        require(_defaultQuorum <= 10000 && _defaultMajority <= 10000, "Invalid percentage");
        
        minProposalDuration = _minDuration;
        maxProposalDuration = _maxDuration;
        defaultQuorum = _defaultQuorum;
        defaultMajority = _defaultMajority;
        proposalDeposit = _proposalDeposit;
    }
    
    /**
     * @dev 暂停/恢复系统
     * @param pause 是否暂停
     */
    function setPaused(bool pause) public onlyAdmin {
        isPaused = pause;
        if (pause) {
            emit SystemPaused(msg.sender);
        } else {
            emit SystemUnpaused(msg.sender);
        }
    }
    
    /**
     * @dev 转移管理权
     * @param newAdmin 新管理员地址
     */
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        require(newAdmin != admin, "Same admin address");
        
        admin = newAdmin;
        
        // 新管理员自动获得投票资格
        if (!voters[newAdmin].isEligible) {
            _registerVoter(newAdmin, 100);
        }
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 内部注册投票者函数
     * @param voter 投票者地址
     * @param weight 投票权重
     */
    function _registerVoter(address voter, uint256 weight) internal {
        require(voter != address(0), "Invalid voter address");
        require(weight > 0, "Weight must be positive");
        
        if (!voters[voter].isEligible) {
            totalVoters++;
        } else {
            // 如果已经是投票者，更新总权重
            totalVotingWeight -= voters[voter].weight;
        }
        
        voters[voter] = Voter({
            isEligible: true,
            weight: weight,
            reputation: 100, // 默认声誉值
            joinTime: block.timestamp,
            isDelegate: false,
            delegatedTo: address(0),
            delegatedWeight: 0
        });
        
        totalVotingWeight += weight;
        
        emit VoterRegistered(voter, weight);
    }
    
    /**
     * @dev 初始化提案类型配置
     */
    function _initializeProposalTypeConfigs() internal {
        // 一般提案：10%法定人数，50%多数
        typeQuorum[ProposalType.GENERAL] = 1000;
        typeMajority[ProposalType.GENERAL] = 5000;
        typeDeposit[ProposalType.GENERAL] = 0.1 ether;
        
        // 宪法修改：30%法定人数，67%多数
        typeQuorum[ProposalType.CONSTITUTIONAL] = 3000;
        typeMajority[ProposalType.CONSTITUTIONAL] = 6700;
        typeDeposit[ProposalType.CONSTITUTIONAL] = 1 ether;
        
        // 预算提案：20%法定人数，60%多数
        typeQuorum[ProposalType.BUDGET] = 2000;
        typeMajority[ProposalType.BUDGET] = 6000;
        typeDeposit[ProposalType.BUDGET] = 0.5 ether;
        
        // 技术升级：25%法定人数，67%多数
        typeQuorum[ProposalType.TECHNICAL] = 2500;
        typeMajority[ProposalType.TECHNICAL] = 6700;
        typeDeposit[ProposalType.TECHNICAL] = 0.5 ether;
        
        // 紧急提案：15%法定人数，75%多数
        typeQuorum[ProposalType.EMERGENCY] = 1500;
        typeMajority[ProposalType.EMERGENCY] = 7500;
        typeDeposit[ProposalType.EMERGENCY] = 0.2 ether;
    }
    
    // ============ 应急功能 ============
    
    /**
     * @dev 应急提取合约余额
     */
    function emergencyWithdraw() public onlyAdmin {
        require(address(this).balance > 0, "No balance to withdraw");
        payable(admin).transfer(address(this).balance);
    }
    
    /**
     * @dev 接收以太币
     */
    receive() external payable {
        // 接收押金和其他支付
    }
}

/**
 * 个人学习笔记 - 唐秋平
 * 
 * 实用主义投票系统设计的核心要素：
 * 1. 用户体验优先：简化操作流程、批量功能、清晰的状态查询
 * 2. 灵活的治理机制：多种提案类型、可配置参数、委托投票
 * 3. 实用的管理功能：批量操作、统计分析、应急处理
 * 4. 完善的查询接口：状态查询、用户画像、系统概览
 * 
 * 实际治理场景考虑：
 * - 不同类型提案需要不同的通过标准
 * - 委托投票机制提高参与度
 * - 押金机制防止垃圾提案
 * - 批量操作提高管理效率
 * - 详细的统计数据支持决策分析
 * 
 * 实用功能的设计思路：
 * - 简化常用操作：快速创建提案、批量投票
 * - 提供丰富查询：用户统计、系统概览、提案详情
 * - 灵活的配置：不同类型不同要求、可调整参数
 * - 完善的权限管理：管理员功能、投票者管理
 * 
 * 用户友好性体现：
 * - 清晰的状态枚举和查询接口
 * - 详细的事件记录便于追踪
 * - 合理的默认参数和限制
 * - 完善的错误提示和验证
 * 
 * 实用主义vs理想主义的权衡：
 * - 不追求理论上的完美民主，关注实际可操作性
 * - 在去中心化和效率之间找平衡
 * - 优先实现高频使用的治理功能
 * - 保持系统的简单性和可理解性
 * 
 * 学习心得：
 * - 理解了实际DAO治理中的常见需求和挑战
 * - 学会了从用户角度设计治理流程
 * - 掌握了投票系统中的权重机制和委托机制
 * - 认识到统计分析功能对治理决策的重要性
 * - 体会到了实用性比理论完美更重要的道理
 */