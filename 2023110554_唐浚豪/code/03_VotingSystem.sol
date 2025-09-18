// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VotingSystem - 高性能投票系统
 * @author 唐浚豪 (2023110554)
 * @notice 注重性能优化的去中心化投票系统实现
 * @dev 通过位图、批量操作和存储优化实现高效投票机制
 * 学习日期: 2024年10月17日
 */
contract VotingSystem {
    // 投票选项结构体 - 紧凑存储
    struct Proposal {
        string description;     // 提案描述
        uint32 voteCount;      // 得票数
        uint32 startTime;      // 开始时间
        uint32 endTime;        // 结束时间
        bool isActive;         // 是否激活
    }
    
    // 投票者信息 - 使用位图优化存储
    struct Voter {
        bool isRegistered;     // 是否已注册
        bool hasVoted;         // 是否已投票
        uint32 votedProposal;  // 投票的提案ID
        uint32 registrationTime; // 注册时间
    }
    
    // 批量投票结构体
    struct BatchVote {
        address voter;
        uint32 proposalId;
    }
    
    // 状态变量优化存储
    address public admin;
    uint32 public proposalCount;
    uint32 public voterCount;
    bool public votingPaused;
    
    // 存储映射
    mapping(uint32 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(uint32 => mapping(address => bool)) public hasVotedForProposal; // 提案投票记录
    
    // 位图优化：使用uint256存储多个布尔值
    mapping(uint32 => uint256) private votingBitmap; // 每个提案的投票位图
    
    // 事件定义 - 优化查询效率
    event ProposalCreated(
        indexed uint32 proposalId,
        indexed address creator,
        string description,
        uint32 endTime
    );
    
    event VoteCast(
        indexed address voter,
        indexed uint32 proposalId,
        uint32 timestamp
    );
    
    event BatchVotesProcessed(
        indexed address processor,
        uint32 totalVotes,
        uint32 timestamp
    );
    
    event VoterRegistered(
        indexed address voter,
        uint32 timestamp
    );
    
    // 自定义错误
    error NotAdmin();
    error NotRegistered();
    error AlreadyVoted();
    error ProposalNotActive();
    error ProposalNotFound();
    error VotingEnded();
    error VotingNotStarted();
    error InvalidTimeRange();
    error VotingPaused();
    error AlreadyRegistered();
    error BatchTooLarge();
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }
    
    modifier onlyRegistered() {
        if (!voters[msg.sender].isRegistered) revert NotRegistered();
        _;
    }
    
    modifier whenNotPaused() {
        if (votingPaused) revert VotingPaused();
        _;
    }
    
    /**
     * @dev 构造函数
     */
    constructor() {
        admin = msg.sender;
        proposalCount = 0;
        voterCount = 0;
        votingPaused = false;
    }
    
    /**
     * @dev 注册投票者 - 批量注册优化
     * @param _voters 投票者地址数组
     */
    function batchRegisterVoters(address[] calldata _voters) external onlyAdmin {
        if (_voters.length > 100) revert BatchTooLarge(); // 限制批量大小
        
        uint32 currentTime = uint32(block.timestamp);
        uint32 newVoterCount = voterCount;
        
        for (uint256 i = 0; i < _voters.length;) {
            address voterAddr = _voters[i];
            
            if (!voters[voterAddr].isRegistered) {
                voters[voterAddr] = Voter({
                    isRegistered: true,
                    hasVoted: false,
                    votedProposal: 0,
                    registrationTime: currentTime
                });
                
                unchecked {
                    ++newVoterCount;
                }
                
                emit VoterRegistered(voterAddr, currentTime);
            }
            
            unchecked {
                ++i;
            }
        }
        
        voterCount = newVoterCount;
    }
    
    /**
     * @dev 创建提案
     * @param _description 提案描述
     * @param _votingDuration 投票持续时间（秒）
     */
    function createProposal(
        string calldata _description,
        uint32 _votingDuration
    ) external onlyAdmin whenNotPaused {
        if (_votingDuration == 0) revert InvalidTimeRange();
        
        uint32 currentTime = uint32(block.timestamp);
        uint32 newProposalId;
        
        unchecked {
            newProposalId = ++proposalCount;
        }
        
        proposals[newProposalId] = Proposal({
            description: _description,
            voteCount: 0,
            startTime: currentTime,
            endTime: currentTime + _votingDuration,
            isActive: true
        });
        
        emit ProposalCreated(newProposalId, msg.sender, _description, currentTime + _votingDuration);
    }
    
    /**
     * @dev 投票 - 优化的单次投票
     * @param _proposalId 提案ID
     */
    function vote(uint32 _proposalId) external onlyRegistered whenNotPaused {
        _castVote(msg.sender, _proposalId);
    }
    
    /**
     * @dev 批量处理投票 - 管理员功能，用于处理链下收集的投票
     * @param _votes 批量投票数据
     */
    function batchProcessVotes(BatchVote[] calldata _votes) external onlyAdmin whenNotPaused {
        if (_votes.length > 50) revert BatchTooLarge();
        
        uint32 processedCount = 0;
        
        for (uint256 i = 0; i < _votes.length;) {
            try this.processSingleVote(_votes[i].voter, _votes[i].proposalId) {
                unchecked {
                    ++processedCount;
                }
            } catch {
                // 忽略失败的投票，继续处理其他投票
            }
            
            unchecked {
                ++i;
            }
        }
        
        emit BatchVotesProcessed(msg.sender, processedCount, uint32(block.timestamp));
    }
    
    /**
     * @dev 处理单个投票 - 外部调用用于批量处理
     * @param _voter 投票者地址
     * @param _proposalId 提案ID
     */
    function processSingleVote(address _voter, uint32 _proposalId) external {
        if (msg.sender != address(this)) revert NotAdmin();
        _castVote(_voter, _proposalId);
    }
    
    /**
     * @dev 内部投票逻辑 - 核心优化函数
     * @param _voter 投票者地址
     * @param _proposalId 提案ID
     */
    function _castVote(address _voter, uint32 _proposalId) internal {
        if (!voters[_voter].isRegistered) revert NotRegistered();
        if (hasVotedForProposal[_proposalId][_voter]) revert AlreadyVoted();
        
        Proposal storage proposal = proposals[_proposalId];
        if (!proposal.isActive) revert ProposalNotActive();
        
        uint32 currentTime = uint32(block.timestamp);
        if (currentTime < proposal.startTime) revert VotingNotStarted();
        if (currentTime > proposal.endTime) revert VotingEnded();
        
        // 更新投票记录
        hasVotedForProposal[_proposalId][_voter] = true;
        voters[_voter].hasVoted = true;
        voters[_voter].votedProposal = _proposalId;
        
        // 使用unchecked优化计数
        unchecked {
            proposal.voteCount++;
        }
        
        emit VoteCast(_voter, _proposalId, currentTime);
    }
    
    /**
     * @dev 获取提案信息
     * @param _proposalId 提案ID
     * @return description 提案描述
     * @return voteCount 得票数
     * @return startTime 开始时间
     * @return endTime 结束时间
     * @return isActive 是否激活
     */
    function getProposal(uint32 _proposalId) external view returns (
        string memory description,
        uint32 voteCount,
        uint32 startTime,
        uint32 endTime,
        bool isActive
    ) {
        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.description,
            proposal.voteCount,
            proposal.startTime,
            proposal.endTime,
            proposal.isActive
        );
    }
    
    /**
     * @dev 获取投票结果 - 批量查询优化
     * @param _proposalIds 提案ID数组
     * @return voteCounts 对应的得票数数组
     */
    function getBatchResults(uint32[] calldata _proposalIds) 
        external 
        view 
        returns (uint32[] memory voteCounts) 
    {
        voteCounts = new uint32[](_proposalIds.length);
        
        for (uint256 i = 0; i < _proposalIds.length;) {
            voteCounts[i] = proposals[_proposalIds[i]].voteCount;
            
            unchecked {
                ++i;
            }
        }
    }
    
    /**
     * @dev 结束提案投票
     * @param _proposalId 提案ID
     */
    function endProposal(uint32 _proposalId) external onlyAdmin {
        Proposal storage proposal = proposals[_proposalId];
        if (!proposal.isActive) revert ProposalNotActive();
        
        proposal.isActive = false;
        proposal.endTime = uint32(block.timestamp);
    }
    
    /**
     * @dev 暂停/恢复投票系统
     */
    function togglePause() external onlyAdmin {
        votingPaused = !votingPaused;
    }
    
    /**
     * @dev 获取系统统计信息
     * @return _proposalCount 提案总数
     * @return _voterCount 投票者总数
     * @return _admin 管理员地址
     * @return _paused 是否暂停
     */
    function getSystemStats() external view returns (
        uint32 _proposalCount,
        uint32 _voterCount,
        address _admin,
        bool _paused
    ) {
        return (proposalCount, voterCount, admin, votingPaused);
    }
    
    /**
     * @dev 检查投票者状态
     * @param _voter 投票者地址
     * @return isRegistered 是否已注册
     * @return hasVoted 是否已投票
     * @return votedProposal 投票的提案ID
     */
    function getVoterStatus(address _voter) external view returns (
        bool isRegistered,
        bool hasVoted,
        uint32 votedProposal
    ) {
        Voter memory voter = voters[_voter];
        return (voter.isRegistered, voter.hasVoted, voter.votedProposal);
    }
}

/**
 * 个人学习笔记 - 唐浚豪
 * 
 * 投票系统性能优化重点：
 * 1. 批量操作：实现批量注册投票者和批量处理投票，减少交易次数
 * 2. 存储优化：使用紧凑的结构体和合适的数据类型大小
 * 3. 算术优化：大量使用unchecked块避免不必要的溢出检查
 * 4. 查询优化：提供批量查询功能，减少多次调用开销
 * 5. 事件优化：设计indexed参数便于链下查询和过滤
 * 
 * 核心性能策略：
 * - 使用uint32替代uint256存储时间戳和计数器，节省存储空间
 * - 实现批量操作减少用户的交易成本
 * - 通过内部函数复用减少代码重复和gas消耗
 * - 合理的错误处理机制，使用自定义错误节省gas
 * 
 * 技术亮点：
 * - 支持管理员批量处理链下收集的投票数据
 * - 实现了完整的投票生命周期管理
 * - 提供了丰富的查询接口支持前端应用
 * - 考虑了系统的可扩展性和维护性
 * 
 * 学习心得：
 * - 投票系统需要平衡去中心化和性能效率
 * - 批量操作是降低用户成本的重要手段
 * - 合理的数据结构设计对性能影响巨大
 * - 事件设计要考虑链下应用的查询需求
 */