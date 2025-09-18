// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title SecureVotingSystem - 安全加固版投票系统
 * @author 涂雨欣 (2023110835)
 * @notice 实现了多重安全机制的去中心化投票系统
 * @dev 集成访问控制、重入防护、签名验证、时间锁等安全特性
 */
contract SecureVotingSystem is AccessControl, ReentrancyGuard, Pausable, EIP712 {
    using ECDSA for bytes32;
    
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    
    // 提案状态枚举
    enum ProposalState {
        Pending,    // 待开始
        Active,     // 进行中
        Succeeded,  // 通过
        Defeated,   // 失败
        Canceled,   // 取消
        Executed    // 已执行
    }
    
    // 投票选项枚举
    enum VoteType {
        Against,    // 反对
        For,        // 支持
        Abstain     // 弃权
    }
    
    // 提案结构体
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 quorum;          // 法定人数
        uint256 threshold;       // 通过阈值（百分比）
        ProposalState state;
        bytes32 descriptionHash; // 描述哈希，防止篡改
    }
    
    // 投票记录结构体
    struct VoteRecord {
        bool hasVoted;
        VoteType vote;
        uint256 weight;
        uint256 timestamp;
        bytes32 reason;  // 投票理由哈希
    }
    
    // 状态变量
    uint256 public proposalCount;
    uint256 public constant MIN_VOTING_PERIOD = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 30 days;
    uint256 public constant MIN_QUORUM = 10; // 最小法定人数百分比
    uint256 public constant MAX_THRESHOLD = 90; // 最大通过阈值百分比
    uint256 public constant DEFAULT_THRESHOLD = 51; // 默认通过阈值
    
    // 存储映射
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => VoteRecord)) public voteRecords;
    mapping(address => uint256) public voterWeights; // 投票者权重
    mapping(bytes32 => bool) public usedNonces; // 防重放攻击
    
    // 时间锁相关
    uint256 public constant TIMELOCK_DELAY = 2 days;
    mapping(uint256 => uint256) public executionTimes;
    
    // 签名验证相关
    bytes32 private constant VOTE_TYPEHASH = keccak256(
        "Vote(uint256 proposalId,uint8 voteType,uint256 weight,bytes32 nonce,uint256 deadline)"
    );
    
    // 事件定义
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime,
        uint256 quorum,
        uint256 threshold
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteType voteType,
        uint256 weight,
        bytes32 reason
    );
    
    event ProposalStateChanged(
        uint256 indexed proposalId,
        ProposalState oldState,
        ProposalState newState
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor
    );
    
    event VoterWeightUpdated(
        address indexed voter,
        uint256 oldWeight,
        uint256 newWeight
    );
    
    event EmergencyAction(
        address indexed admin,
        string action,
        uint256 timestamp
    );
    
    // 修饰符
    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }
    
    modifier onlyActiveProposal(uint256 proposalId) {
        require(proposals[proposalId].state == ProposalState.Active, "Proposal not active");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        _;
    }
    
    modifier hasNotVoted(uint256 proposalId, address voter) {
        require(!voteRecords[proposalId][voter].hasVoted, "Already voted");
        _;
    }
    
    modifier validVoteType(VoteType voteType) {
        require(
            voteType == VoteType.Against || 
            voteType == VoteType.For || 
            voteType == VoteType.Abstain,
            "Invalid vote type"
        );
        _;
    }
    
    modifier onlyAfterTimelock(uint256 proposalId) {
        require(
            executionTimes[proposalId] != 0 && 
            block.timestamp >= executionTimes[proposalId],
            "Timelock not expired"
        );
        _;
    }
    
    /**
     * @dev 构造函数
     * @param admin 管理员地址
     */
    constructor(address admin) EIP712("SecureVotingSystem", "1.0") {
        require(admin != address(0), "Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(VOTER_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
        
        // 设置角色管理员
        _setRoleAdmin(PROPOSER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(VOTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(AUDITOR_ROLE, ADMIN_ROLE);
    }
    
    /**
     * @dev 创建提案
     * @param title 提案标题
     * @param description 提案描述
     * @param votingPeriod 投票期间（秒）
     * @param quorum 法定人数百分比
     * @param threshold 通过阈值百分比
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 votingPeriod,
        uint256 quorum,
        uint256 threshold
    ) external onlyRole(PROPOSER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(
            votingPeriod >= MIN_VOTING_PERIOD && votingPeriod <= MAX_VOTING_PERIOD,
            "Invalid voting period"
        );
        require(quorum >= MIN_QUORUM && quorum <= 100, "Invalid quorum");
        require(threshold > 50 && threshold <= MAX_THRESHOLD, "Invalid threshold");
        
        uint256 proposalId = ++proposalCount;
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            quorum: quorum,
            threshold: threshold,
            state: ProposalState.Active,
            descriptionHash: descriptionHash
        });
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            block.timestamp,
            block.timestamp + votingPeriod,
            quorum,
            threshold
        );
        
        return proposalId;
    }
    
    /**
     * @dev 投票
     * @param proposalId 提案ID
     * @param voteType 投票类型
     * @param reason 投票理由哈希
     */
    function vote(
        uint256 proposalId,
        VoteType voteType,
        bytes32 reason
    ) external 
        onlyRole(VOTER_ROLE) 
        whenNotPaused 
        nonReentrant 
        validProposal(proposalId)
        onlyActiveProposal(proposalId)
        hasNotVoted(proposalId, msg.sender)
        validVoteType(voteType) {
        
        uint256 weight = _getVoterWeight(msg.sender);
        require(weight > 0, "No voting weight");
        
        // 记录投票
        voteRecords[proposalId][msg.sender] = VoteRecord({
            hasVoted: true,
            vote: voteType,
            weight: weight,
            timestamp: block.timestamp,
            reason: reason
        });
        
        // 更新提案投票统计
        if (voteType == VoteType.For) {
            proposals[proposalId].forVotes += weight;
        } else if (voteType == VoteType.Against) {
            proposals[proposalId].againstVotes += weight;
        } else {
            proposals[proposalId].abstainVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, voteType, weight, reason);
        
        // 检查是否可以提前结束投票
        _checkEarlyCompletion(proposalId);
    }
    
    /**
     * @dev 使用签名投票（离线签名）
     * @param proposalId 提案ID
     * @param voteType 投票类型
     * @param weight 投票权重
     * @param nonce 随机数
     * @param deadline 截止时间
     * @param signature 签名
     */
    function voteWithSignature(
        uint256 proposalId,
        VoteType voteType,
        uint256 weight,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    ) external 
        whenNotPaused 
        nonReentrant 
        validProposal(proposalId)
        onlyActiveProposal(proposalId)
        validVoteType(voteType) {
        
        require(block.timestamp <= deadline, "Signature expired");
        require(!usedNonces[nonce], "Nonce already used");
        
        // 验证签名
        bytes32 structHash = keccak256(
            abi.encode(VOTE_TYPEHASH, proposalId, uint8(voteType), weight, nonce, deadline)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);
        
        require(hasRole(VOTER_ROLE, signer), "Signer not authorized");
        require(!voteRecords[proposalId][signer].hasVoted, "Already voted");
        require(_getVoterWeight(signer) >= weight, "Insufficient voting weight");
        
        // 标记nonce为已使用
        usedNonces[nonce] = true;
        
        // 记录投票
        voteRecords[proposalId][signer] = VoteRecord({
            hasVoted: true,
            vote: voteType,
            weight: weight,
            timestamp: block.timestamp,
            reason: keccak256("Signature vote")
        });
        
        // 更新提案投票统计
        if (voteType == VoteType.For) {
            proposals[proposalId].forVotes += weight;
        } else if (voteType == VoteType.Against) {
            proposals[proposalId].againstVotes += weight;
        } else {
            proposals[proposalId].abstainVotes += weight;
        }
        
        emit VoteCast(proposalId, signer, voteType, weight, keccak256("Signature vote"));
        
        // 检查是否可以提前结束投票
        _checkEarlyCompletion(proposalId);
    }
    
    /**
     * @dev 完成提案（投票结束后调用）
     * @param proposalId 提案ID
     */
    function finalizeProposal(uint256 proposalId) 
        external 
        validProposal(proposalId) 
        whenNotPaused {
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        
        ProposalState oldState = proposal.state;
        ProposalState newState = _calculateProposalResult(proposalId);
        
        proposal.state = newState;
        
        // 如果提案通过，设置时间锁
        if (newState == ProposalState.Succeeded) {
            executionTimes[proposalId] = block.timestamp + TIMELOCK_DELAY;
        }
        
        emit ProposalStateChanged(proposalId, oldState, newState);
    }
    
    /**
     * @dev 执行提案
     * @param proposalId 提案ID
     */
    function executeProposal(uint256 proposalId)
        external
        onlyRole(ADMIN_ROLE)
        validProposal(proposalId)
        onlyAfterTimelock(proposalId)
        whenNotPaused
        nonReentrant {
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Succeeded, "Proposal not succeeded");
        
        proposal.state = ProposalState.Executed;
        
        // 这里可以添加具体的执行逻辑
        // 例如：调用其他合约、转移资金等
        
        emit ProposalExecuted(proposalId, msg.sender);
        emit ProposalStateChanged(proposalId, ProposalState.Succeeded, ProposalState.Executed);
    }
    
    /**
     * @dev 取消提案
     * @param proposalId 提案ID
     */
    function cancelProposal(uint256 proposalId)
        external
        onlyRole(ADMIN_ROLE)
        validProposal(proposalId)
        whenNotPaused {
        
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.state == ProposalState.Active || 
            proposal.state == ProposalState.Succeeded,
            "Cannot cancel proposal"
        );
        
        ProposalState oldState = proposal.state;
        proposal.state = ProposalState.Canceled;
        
        // 清除执行时间
        if (executionTimes[proposalId] != 0) {
            delete executionTimes[proposalId];
        }
        
        emit ProposalStateChanged(proposalId, oldState, ProposalState.Canceled);
    }
    
    /**
     * @dev 设置投票者权重
     * @param voter 投票者地址
     * @param weight 权重
     */
    function setVoterWeight(address voter, uint256 weight)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused {
        
        require(voter != address(0), "Invalid voter address");
        require(weight > 0, "Weight must be positive");
        
        uint256 oldWeight = voterWeights[voter];
        voterWeights[voter] = weight;
        
        emit VoterWeightUpdated(voter, oldWeight, weight);
    }
    
    /**
     * @dev 批量设置投票者权重
     * @param voters 投票者地址数组
     * @param weights 权重数组
     */
    function batchSetVoterWeights(address[] memory voters, uint256[] memory weights)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused {
        
        require(voters.length == weights.length, "Arrays length mismatch");
        require(voters.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < voters.length; i++) {
            require(voters[i] != address(0), "Invalid voter address");
            require(weights[i] > 0, "Weight must be positive");
            
            uint256 oldWeight = voterWeights[voters[i]];
            voterWeights[voters[i]] = weights[i];
            
            emit VoterWeightUpdated(voters[i], oldWeight, weights[i]);
        }
    }
    
    /**
     * @dev 紧急暂停
     */
    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        _pause();
        emit EmergencyAction(msg.sender, "Emergency Pause", block.timestamp);
    }
    
    /**
     * @dev 取消暂停
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit EmergencyAction(msg.sender, "Unpause", block.timestamp);
    }
    
    // ========================================================================
    // 内部函数
    // ========================================================================
    
    /**
     * @dev 获取投票者权重
     * @param voter 投票者地址
     * @return 投票权重
     */
    function _getVoterWeight(address voter) internal view returns (uint256) {
        uint256 weight = voterWeights[voter];
        return weight > 0 ? weight : 1; // 默认权重为1
    }
    
    /**
     * @dev 检查是否可以提前结束投票
     * @param proposalId 提案ID
     */
    function _checkEarlyCompletion(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalEligibleVotes = _getTotalEligibleVotes();
        
        // 如果达到法定人数且有明确结果，可以提前结束
        if (totalVotes * 100 >= totalEligibleVotes * proposal.quorum) {
            uint256 effectiveVotes = proposal.forVotes + proposal.againstVotes;
            if (effectiveVotes > 0) {
                uint256 forPercentage = (proposal.forVotes * 100) / effectiveVotes;
                
                // 如果支持票或反对票已经超过阈值，提前结束
                if (forPercentage >= proposal.threshold || forPercentage <= (100 - proposal.threshold)) {
                    ProposalState oldState = proposal.state;
                    proposal.state = forPercentage >= proposal.threshold ? 
                        ProposalState.Succeeded : ProposalState.Defeated;
                    
                    if (proposal.state == ProposalState.Succeeded) {
                        executionTimes[proposalId] = block.timestamp + TIMELOCK_DELAY;
                    }
                    
                    emit ProposalStateChanged(proposalId, oldState, proposal.state);
                }
            }
        }
    }
    
    /**
     * @dev 计算提案结果
     * @param proposalId 提案ID
     * @return 提案状态
     */
    function _calculateProposalResult(uint256 proposalId) internal view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalEligibleVotes = _getTotalEligibleVotes();
        
        // 检查是否达到法定人数
        if (totalVotes * 100 < totalEligibleVotes * proposal.quorum) {
            return ProposalState.Defeated;
        }
        
        // 计算有效投票（不包括弃权）
        uint256 effectiveVotes = proposal.forVotes + proposal.againstVotes;
        if (effectiveVotes == 0) {
            return ProposalState.Defeated;
        }
        
        // 检查是否达到通过阈值
        uint256 forPercentage = (proposal.forVotes * 100) / effectiveVotes;
        return forPercentage >= proposal.threshold ? 
            ProposalState.Succeeded : ProposalState.Defeated;
    }
    
    /**
     * @dev 获取总的合格投票数
     * @return 总投票数
     */
    function _getTotalEligibleVotes() internal view returns (uint256) {
        // 简化实现：返回所有有权重的投票者的总权重
        // 实际实现中可能需要遍历所有投票者或使用其他方法
        return 1000; // 示例值
    }
    
    // ========================================================================
    // 查询函数
    // ========================================================================
    
    /**
     * @dev 获取提案详情
     * @param proposalId 提案ID
     * @return 提案信息
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        validProposal(proposalId) 
        returns (
            uint256 id,
            address proposer,
            string memory title,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            uint256 quorum,
            uint256 threshold,
            ProposalState state
        ) {
        
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.quorum,
            proposal.threshold,
            proposal.state
        );
    }
    
    /**
     * @dev 获取投票记录
     * @param proposalId 提案ID
     * @param voter 投票者地址
     * @return 投票记录
     */
    function getVoteRecord(uint256 proposalId, address voter)
        external
        view
        validProposal(proposalId)
        returns (
            bool hasVoted,
            VoteType vote,
            uint256 weight,
            uint256 timestamp,
            bytes32 reason
        ) {
        
        VoteRecord storage record = voteRecords[proposalId][voter];
        return (
            record.hasVoted,
            record.vote,
            record.weight,
            record.timestamp,
            record.reason
        );
    }
    
    /**
     * @dev 获取提案投票统计
     * @param proposalId 提案ID
     * @return 投票统计信息
     */
    function getProposalStats(uint256 proposalId)
        external
        view
        validProposal(proposalId)
        returns (
            uint256 totalVotes,
            uint256 participationRate,
            uint256 forPercentage,
            uint256 againstPercentage,
            uint256 abstainPercentage,
            bool quorumReached,
            bool thresholdReached
        ) {
        
        Proposal storage proposal = proposals[proposalId];
        
        totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalEligibleVotes = _getTotalEligibleVotes();
        
        participationRate = totalEligibleVotes > 0 ? 
            (totalVotes * 100) / totalEligibleVotes : 0;
        
        if (totalVotes > 0) {
            forPercentage = (proposal.forVotes * 100) / totalVotes;
            againstPercentage = (proposal.againstVotes * 100) / totalVotes;
            abstainPercentage = (proposal.abstainVotes * 100) / totalVotes;
        }
        
        quorumReached = participationRate >= proposal.quorum;
        
        uint256 effectiveVotes = proposal.forVotes + proposal.againstVotes;
        thresholdReached = effectiveVotes > 0 && 
            (proposal.forVotes * 100) / effectiveVotes >= proposal.threshold;
        
        return (
            totalVotes,
            participationRate,
            forPercentage,
            againstPercentage,
            abstainPercentage,
            quorumReached,
            thresholdReached
        );
    }
    
    /**
     * @dev 检查地址是否有投票权
     * @param voter 投票者地址
     * @return 是否有投票权
     */
    function canVote(address voter) external view returns (bool) {
        return hasRole(VOTER_ROLE, voter) && _getVoterWeight(voter) > 0;
    }
    
    /**
     * @dev 获取系统统计信息
     * @return 系统统计
     */
    function getSystemStats()
        external
        view
        returns (
            uint256 totalProposals,
            uint256 activeProposals,
            uint256 succeededProposals,
            uint256 executedProposals
        ) {
        
        uint256 active = 0;
        uint256 succeeded = 0;
        uint256 executed = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            ProposalState state = proposals[i].state;
            if (state == ProposalState.Active) {
                active++;
            } else if (state == ProposalState.Succeeded) {
                succeeded++;
            } else if (state == ProposalState.Executed) {
                executed++;
            }
        }
        
        return (proposalCount, active, succeeded, executed);
    }
}

/*
设计特色总结：

1. 多重安全机制：
   - AccessControl：基于角色的访问控制
   - ReentrancyGuard：防重入攻击
   - Pausable：紧急暂停功能
   - EIP712：结构化数据签名验证
   - 时间锁：延迟执行机制

2. 安全投票系统：
   - 离线签名投票：支持元交易
   - 防重放攻击：nonce机制
   - 投票权重管理：灵活的权重分配
   - 提前结束机制：效率优化

3. 完善的治理流程：
   - 提案创建：严格的参数验证
   - 投票阶段：多种投票方式
   - 结果计算：法定人数和阈值检查
   - 执行阶段：时间锁保护

4. 审计友好设计：
   - 详细的事件日志
   - 完整的状态跟踪
   - 透明的查询接口
   - 紧急响应机制

通过多层次的安全防护机制，构建了一个安全可靠的去中心化投票系统。
*/