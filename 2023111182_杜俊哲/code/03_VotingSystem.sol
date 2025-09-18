// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title 模块化投票治理系统
 * @dev 展示清晰模块分离和可扩展设计的投票合约
 * @author 杜俊哲 (2023111182)
 * @notice 使用模块化架构构建的治理投票系统
 */

// ============================================================================
// 核心接口模块
// ============================================================================

/**
 * @dev 投票治理核心接口
 */
interface IGovernance {
    function propose(string memory description, bytes memory callData) external returns (uint256);
    function vote(uint256 proposalId, uint8 support) external;
    function execute(uint256 proposalId) external;
    function cancel(uint256 proposalId) external;
    
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
}

/**
 * @dev 投票权重接口
 */
interface IVotingWeight {
    function getVotingWeight(address account) external view returns (uint256);
    function delegate(address delegatee) external;
    function undelegate() external;
    
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
}

/**
 * @dev 提案生命周期接口
 */
interface IProposalLifecycle {
    function getProposalState(uint256 proposalId) external view returns (uint8);
    function getProposalDeadline(uint256 proposalId) external view returns (uint256);
    function getProposalSnapshot(uint256 proposalId) external view returns (uint256);
    
    event ProposalStateChanged(uint256 indexed proposalId, uint8 oldState, uint8 newState);
}

/**
 * @dev 时间锁接口
 */
interface ITimelock {
    function delay() external view returns (uint256);
    function queueTransaction(bytes32 txHash, uint256 eta) external;
    function executeTransaction(bytes32 txHash) external;
    function cancelTransaction(bytes32 txHash) external;
    
    event QueueTransaction(bytes32 indexed txHash, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash);
    event CancelTransaction(bytes32 indexed txHash);
}

/**
 * @dev 投票策略接口
 */
interface IVotingStrategy {
    function calculateVotingPower(address voter, uint256 blockNumber) external view returns (uint256);
    function isEligibleToVote(address voter, uint256 proposalId) external view returns (bool);
    function getQuorum(uint256 proposalId) external view returns (uint256);
}

// ============================================================================
// 抽象基础模块
// ============================================================================

/**
 * @dev 上下文抽象合约
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev 访问控制抽象合约
 */
abstract contract AccessControl is Context {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    
    mapping(bytes32 => RoleData) private _roles;
    
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()), "AccessControl: missing role");
        _;
    }
    
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].members[account];
    }
    
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }
    
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }
    
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        _roles[role].adminRole = adminRole;
    }
}

/**
 * @dev 可暂停抽象合约
 */
abstract contract Pausable is Context {
    bool private _paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    constructor() {
        _paused = false;
    }
    
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// ============================================================================
// 数据存储模块
// ============================================================================

/**
 * @dev 治理数据存储模块
 */
contract GovernanceStorage {
    // 提案状态枚举
    enum ProposalState {
        Pending,    // 待开始
        Active,     // 投票中
        Canceled,   // 已取消
        Defeated,   // 被否决
        Succeeded,  // 通过
        Queued,     // 队列中
        Expired,    // 已过期
        Executed    // 已执行
    }
    
    // 投票选择枚举
    enum VoteType {
        Against,    // 反对
        For,        // 支持
        Abstain     // 弃权
    }
    
    // 提案结构
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }
    
    // 投票记录结构
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint256 votes;
        uint256 timestamp;
    }
    
    // 委托信息结构
    struct Delegation {
        address delegate;
        uint256 delegatedVotes;
        uint256 timestamp;
    }
    
    // 时间锁交易结构
    struct TimelockTransaction {
        bytes32 txHash;
        uint256 eta;
        bool executed;
        bool canceled;
        bytes data;
    }
    
    // 投票策略配置
    struct VotingConfig {
        uint256 votingDelay;      // 投票延迟
        uint256 votingPeriod;     // 投票周期
        uint256 proposalThreshold; // 提案门槛
        uint256 quorumNumerator;  // 法定人数分子
        uint256 quorumDenominator; // 法定人数分母
    }
    
    // 存储映射
    mapping(uint256 => Proposal) internal _proposals;
    mapping(address => Delegation) internal _delegations;
    mapping(address => mapping(uint256 => uint256)) internal _checkpoints;
    mapping(address => uint256) internal _numCheckpoints;
    mapping(bytes32 => TimelockTransaction) internal _timelockTxs;
    
    // 状态变量
    uint256 internal _proposalCount;
    VotingConfig internal _config;
    uint256 internal _timelockDelay;
    
    // 统计数据
    struct Statistics {
        uint256 totalProposals;
        uint256 totalVotes;
        uint256 activeProposals;
        uint256 executedProposals;
        uint256 totalParticipants;
    }
    
    Statistics internal _stats;
    
    // 事件存储
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 startBlock, uint256 endBlock);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
}

// ============================================================================
// 投票权重管理模块
// ============================================================================

/**
 * @dev 投票权重管理模块
 */
contract VotingWeightManager is GovernanceStorage, IVotingWeight {
    
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event CheckpointCreated(address indexed account, uint256 blockNumber, uint256 votes);
    
    /**
     * @dev 获取投票权重
     */
    function getVotingWeight(address account) public view override returns (uint256) {
        return _getVotesAt(account, block.number - 1);
    }
    
    /**
     * @dev 获取历史投票权重
     */
    function getVotingWeightAt(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "VotingWeight: future block");
        return _getVotesAt(account, blockNumber);
    }
    
    /**
     * @dev 委托投票权
     */
    function delegate(address delegatee) public override {
        _delegate(_msgSender(), delegatee);
    }
    
    /**
     * @dev 取消委托
     */
    function undelegate() public override {
        _delegate(_msgSender(), address(0));
    }
    
    /**
     * @dev 内部委托逻辑
     */
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegations[delegator].delegate;
        uint256 delegatorBalance = _getOwnVotes(delegator);
        
        _delegations[delegator].delegate = delegatee;
        _delegations[delegator].timestamp = block.timestamp;
        
        emit DelegateChanged(delegator, currentDelegate, delegatee);
        
        _moveDelegateVotes(currentDelegate, delegatee, delegatorBalance);
    }
    
    /**
     * @dev 移动委托投票
     */
    function _moveDelegateVotes(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint256 srcRepOld = _getVotesAt(srcRep, block.number - 1);
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNew);
                emit DelegateVotesChanged(srcRep, srcRepOld, srcRepNew);
            }
            
            if (dstRep != address(0)) {
                uint256 dstRepOld = _getVotesAt(dstRep, block.number - 1);
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNew);
                emit DelegateVotesChanged(dstRep, dstRepOld, dstRepNew);
            }
        }
    }
    
    /**
     * @dev 获取自有投票权
     */
    function _getOwnVotes(address account) internal view returns (uint256) {
        // 这里应该从代币合约获取余额，简化处理
        return 100; // 简化实现
    }
    
    /**
     * @dev 获取指定区块的投票数
     */
    function _getVotesAt(address account, uint256 blockNumber) internal view returns (uint256) {
        uint256 nCheckpoints = _numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
        
        // 二分查找
        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            uint256 checkpointBlock = _checkpoints[account][center] >> 128;
            
            if (checkpointBlock == blockNumber) {
                return uint256(uint128(_checkpoints[account][center]));
            } else if (checkpointBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        
        uint256 checkpointBlock = _checkpoints[account][lower] >> 128;
        return checkpointBlock <= blockNumber ? uint256(uint128(_checkpoints[account][lower])) : 0;
    }
    
    /**
     * @dev 写入检查点
     */
    function _writeCheckpoint(address account, uint256 votes) internal {
        uint256 nCheckpoints = _numCheckpoints[account];
        
        if (nCheckpoints > 0) {
            uint256 oldCheckpoint = _checkpoints[account][nCheckpoints - 1];
            uint256 oldBlock = oldCheckpoint >> 128;
            
            if (oldBlock == block.number) {
                _checkpoints[account][nCheckpoints - 1] = (block.number << 128) | votes;
                emit CheckpointCreated(account, block.number, votes);
                return;
            }
        }
        
        _checkpoints[account][nCheckpoints] = (block.number << 128) | votes;
        _numCheckpoints[account] = nCheckpoints + 1;
        
        emit CheckpointCreated(account, block.number, votes);
    }
}

// ============================================================================
// 提案生命周期管理模块
// ============================================================================

/**
 * @dev 提案生命周期管理模块
 */
contract ProposalLifecycleManager is GovernanceStorage, IProposalLifecycle {
    
    event ProposalStateChanged(uint256 indexed proposalId, uint8 oldState, uint8 newState);
    event ProposalThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event VotingConfigChanged(uint256 votingDelay, uint256 votingPeriod, uint256 quorumNumerator);
    
    /**
     * @dev 获取提案状态
     */
    function getProposalState(uint256 proposalId) public view override returns (uint8) {
        require(_proposals[proposalId].id != 0, "ProposalLifecycle: proposal not found");
        
        Proposal storage proposal = _proposals[proposalId];
        
        if (proposal.canceled) {
            return uint8(ProposalState.Canceled);
        }
        
        if (proposal.executed) {
            return uint8(ProposalState.Executed);
        }
        
        if (block.number <= proposal.startBlock) {
            return uint8(ProposalState.Pending);
        }
        
        if (block.number <= proposal.endBlock) {
            return uint8(ProposalState.Active);
        }
        
        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            bytes32 txHash = _getTxHash(proposalId);
            if (_timelockTxs[txHash].eta != 0) {
                if (_timelockTxs[txHash].eta <= block.timestamp) {
                    return uint8(ProposalState.Queued);
                } else {
                    return uint8(ProposalState.Expired);
                }
            }
            return uint8(ProposalState.Succeeded);
        } else {
            return uint8(ProposalState.Defeated);
        }
    }
    
    /**
     * @dev 获取提案截止时间
     */
    function getProposalDeadline(uint256 proposalId) public view override returns (uint256) {
        return _proposals[proposalId].endBlock;
    }
    
    /**
     * @dev 获取提案快照区块
     */
    function getProposalSnapshot(uint256 proposalId) public view override returns (uint256) {
        return _proposals[proposalId].startBlock;
    }
    
    /**
     * @dev 检查法定人数是否达到
     */
    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        
        // 简化的法定人数计算
        uint256 quorum = (_config.quorumNumerator * 1000) / _config.quorumDenominator;
        return totalVotes >= quorum;
    }
    
    /**
     * @dev 检查投票是否成功
     */
    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }
    
    /**
     * @dev 获取交易哈希
     */
    function _getTxHash(uint256 proposalId) internal view returns (bytes32) {
        Proposal storage proposal = _proposals[proposalId];
        return keccak256(abi.encode(proposalId, proposal.callData));
    }
    
    /**
     * @dev 更新提案状态
     */
    function _updateProposalState(uint256 proposalId, ProposalState newState) internal {
        uint8 oldState = getProposalState(proposalId);
        emit ProposalStateChanged(proposalId, oldState, uint8(newState));
    }
    
    /**
     * @dev 设置投票配置
     */
    function setVotingConfig(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumerator,
        uint256 quorumDenominator
    ) external {
        _config.votingDelay = votingDelay;
        _config.votingPeriod = votingPeriod;
        _config.proposalThreshold = proposalThreshold;
        _config.quorumNumerator = quorumNumerator;
        _config.quorumDenominator = quorumDenominator;
        
        emit VotingConfigChanged(votingDelay, votingPeriod, quorumNumerator);
    }
}

// ============================================================================
// 时间锁管理模块
// ============================================================================

/**
 * @dev 时间锁管理模块
 */
contract TimelockManager is GovernanceStorage, ITimelock {
    
    event QueueTransaction(bytes32 indexed txHash, uint256 eta);
    event ExecuteTransaction(bytes32 indexed txHash);
    event CancelTransaction(bytes32 indexed txHash);
    event DelayChanged(uint256 oldDelay, uint256 newDelay);
    
    /**
     * @dev 获取延迟时间
     */
    function delay() public view override returns (uint256) {
        return _timelockDelay;
    }
    
    /**
     * @dev 队列交易
     */
    function queueTransaction(bytes32 txHash, uint256 eta) public override {
        require(eta >= block.timestamp + _timelockDelay, "TimelockManager: eta too early");
        
        _timelockTxs[txHash] = TimelockTransaction({
            txHash: txHash,
            eta: eta,
            executed: false,
            canceled: false,
            data: ""
        });
        
        emit QueueTransaction(txHash, eta);
    }
    
    /**
     * @dev 执行交易
     */
    function executeTransaction(bytes32 txHash) public override {
        TimelockTransaction storage tx = _timelockTxs[txHash];
        
        require(tx.eta != 0, "TimelockManager: transaction not queued");
        require(!tx.executed, "TimelockManager: transaction already executed");
        require(!tx.canceled, "TimelockManager: transaction canceled");
        require(block.timestamp >= tx.eta, "TimelockManager: transaction not ready");
        
        tx.executed = true;
        
        emit ExecuteTransaction(txHash);
    }
    
    /**
     * @dev 取消交易
     */
    function cancelTransaction(bytes32 txHash) public override {
        TimelockTransaction storage tx = _timelockTxs[txHash];
        
        require(tx.eta != 0, "TimelockManager: transaction not queued");
        require(!tx.executed, "TimelockManager: transaction already executed");
        require(!tx.canceled, "TimelockManager: transaction already canceled");
        
        tx.canceled = true;
        
        emit CancelTransaction(txHash);
    }
    
    /**
     * @dev 设置延迟时间
     */
    function setDelay(uint256 newDelay) external {
        require(newDelay >= 1 hours && newDelay <= 30 days, "TimelockManager: invalid delay");
        
        uint256 oldDelay = _timelockDelay;
        _timelockDelay = newDelay;
        
        emit DelayChanged(oldDelay, newDelay);
    }
    
    /**
     * @dev 获取交易信息
     */
    function getTransaction(bytes32 txHash) external view returns (
        uint256 eta,
        bool executed,
        bool canceled
    ) {
        TimelockTransaction storage tx = _timelockTxs[txHash];
        return (tx.eta, tx.executed, tx.canceled);
    }
}

// ============================================================================
// 投票策略模块
// ============================================================================

/**
 * @dev 投票策略模块
 */
contract VotingStrategyManager is GovernanceStorage, VotingWeightManager, IVotingStrategy {
    
    event StrategyChanged(string strategyType, bytes parameters);
    event EligibilityRuleChanged(string ruleType, bytes parameters);
    
    /**
     * @dev 计算投票权力
     */
    function calculateVotingPower(address voter, uint256 blockNumber) public view override returns (uint256) {
        return getVotingWeightAt(voter, blockNumber);
    }
    
    /**
     * @dev 检查投票资格
     */
    function isEligibleToVote(address voter, uint256 proposalId) public view override returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        
        // 检查是否在快照区块有投票权
        uint256 votingPower = calculateVotingPower(voter, proposal.startBlock);
        if (votingPower == 0) {
            return false;
        }
        
        // 检查是否已经投票
        if (proposal.receipts[voter].hasVoted) {
            return false;
        }
        
        // 检查提案是否处于活跃状态
        if (getProposalState(proposalId) != uint8(ProposalState.Active)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev 获取法定人数
     */
    function getQuorum(uint256 proposalId) public view override returns (uint256) {
        // 基于提案快照区块计算法定人数
        return (_config.quorumNumerator * _getTotalSupplyAt(_proposals[proposalId].startBlock)) / _config.quorumDenominator;
    }
    
    /**
     * @dev 获取历史总供应量
     */
    function _getTotalSupplyAt(uint256 blockNumber) internal view returns (uint256) {
        // 简化实现，实际需要从代币合约获取
        return 1000000 * 10**18;
    }
    
    /**
     * @dev 计算投票权重（支持多种策略）
     */
    function calculateWeightedVote(address voter, uint256 proposalId, uint8 support) external view returns (uint256) {
        uint256 basePower = calculateVotingPower(voter, _proposals[proposalId].startBlock);
        
        // 可以根据不同策略调整权重
        // 例如：声誉加权、时间加权、参与度加权等
        
        return basePower;
    }
}

// ============================================================================
// 主治理合约
// ============================================================================

/**
 * @dev 模块化治理主合约
 */
contract ModularGovernance is 
    IGovernance,
    AccessControl,
    Pausable,
    VotingWeightManager,
    ProposalLifecycleManager,
    TimelockManager,
    VotingStrategyManager
{
    
    constructor(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumerator,
        uint256 quorumDenominator,
        uint256 timelockDelay
    ) {
        // 初始化配置
        _config = VotingConfig({
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            proposalThreshold: proposalThreshold,
            quorumNumerator: quorumNumerator,
            quorumDenominator: quorumDenominator
        });
        
        _timelockDelay = timelockDelay;
        _proposalCount = 0;
        
        // 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PROPOSER_ROLE, _msgSender());
        _grantRole(EXECUTOR_ROLE, _msgSender());
        _grantRole(CANCELLER_ROLE, _msgSender());
        
        // 初始化统计
        _stats = Statistics({
            totalProposals: 0,
            totalVotes: 0,
            activeProposals: 0,
            executedProposals: 0,
            totalParticipants: 0
        });
    }
    
    /**
     * @dev 创建提案
     */
    function propose(string memory description, bytes memory callData) 
        public 
        override 
        whenNotPaused 
        returns (uint256) 
    {
        require(getVotingWeight(_msgSender()) >= _config.proposalThreshold, "ModularGovernance: proposer votes below threshold");
        
        uint256 proposalId = ++_proposalCount;
        uint256 startBlock = block.number + _config.votingDelay;
        uint256 endBlock = startBlock + _config.votingPeriod;
        
        Proposal storage proposal = _proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = _msgSender();
        proposal.description = description;
        proposal.callData = callData;
        proposal.startBlock = startBlock;
        proposal.endBlock = endBlock;
        
        _stats.totalProposals++;
        _stats.activeProposals++;
        
        emit ProposalCreated(proposalId, _msgSender(), description, startBlock, endBlock);
        
        return proposalId;
    }
    
    /**
     * @dev 投票
     */
    function vote(uint256 proposalId, uint8 support) public override whenNotPaused {
        require(isEligibleToVote(_msgSender(), proposalId), "ModularGovernance: not eligible to vote");
        
        Proposal storage proposal = _proposals[proposalId];
        Receipt storage receipt = proposal.receipts[_msgSender()];
        
        uint256 weight = calculateVotingPower(_msgSender(), proposal.startBlock);
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = weight;
        receipt.timestamp = block.timestamp;
        
        if (support == uint8(VoteType.Against)) {
            proposal.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposal.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposal.abstainVotes += weight;
        }
        
        _stats.totalVotes++;
        
        emit VoteCast(proposalId, _msgSender(), support, weight, "");
    }
    
    /**
     * @dev 执行提案
     */
    function execute(uint256 proposalId) public override onlyRole(EXECUTOR_ROLE) {
        require(getProposalState(proposalId) == uint8(ProposalState.Succeeded), "ModularGovernance: proposal not succeeded");
        
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;
        
        bytes32 txHash = _getTxHash(proposalId);
        executeTransaction(txHash);
        
        _stats.executedProposals++;
        _stats.activeProposals--;
        
        _updateProposalState(proposalId, ProposalState.Executed);
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev 取消提案
     */
    function cancel(uint256 proposalId) public override onlyRole(CANCELLER_ROLE) {
        require(getProposalState(proposalId) != uint8(ProposalState.Executed), "ModularGovernance: cannot cancel executed proposal");
        
        Proposal storage proposal = _proposals[proposalId];
        proposal.canceled = true;
        
        _stats.activeProposals--;
        
        _updateProposalState(proposalId, ProposalState.Canceled);
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev 获取提案详情
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool canceled,
        bool executed
    ) {
        Proposal storage proposal = _proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.startBlock,
            proposal.endBlock,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.canceled,
            proposal.executed
        );
    }
    
    /**
     * @dev 获取投票记录
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return _proposals[proposalId].receipts[voter];
    }
    
    /**
     * @dev 获取统计信息
     */
    function getStatistics() external view returns (Statistics memory) {
        return _stats;
    }
    
    /**
     * @dev 获取配置信息
     */
    function getConfig() external view returns (VotingConfig memory) {
        return _config;
    }
    
    /**
     * @dev 暂停治理
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复治理
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev 获取模块信息
     */
    function getModuleInfo() external pure returns (
        string memory architecture,
        string[] memory modules,
        string memory version
    ) {
        modules = new string[](7);
        modules[0] = "AccessControl";
        modules[1] = "VotingWeightManager";
        modules[2] = "ProposalLifecycleManager";
        modules[3] = "TimelockManager";
        modules[4] = "VotingStrategyManager";
        modules[5] = "GovernanceStorage";
        modules[6] = "ModularGovernance";
        
        return (
            "Modular Governance Architecture",
            modules,
            "1.0.0"
        );
    }
}

/*
模块化投票治理系统特色：

1. 接口分离设计
   - IGovernance核心治理接口
   - IVotingWeight权重管理接口
   - IProposalLifecycle生命周期接口
   - ITimelock时间锁接口
   - IVotingStrategy投票策略接口

2. 抽象基础模块
   - Context上下文管理
   - AccessControl访问控制
   - Pausable暂停机制
   - 可重用组件设计

3. 数据存储模块
   - GovernanceStorage治理数据
   - 结构化数据管理
   - 状态枚举定义
   - 统计信息存储

4. 功能模块分离
   - VotingWeightManager权重管理
   - ProposalLifecycleManager生命周期
   - TimelockManager时间锁管理
   - VotingStrategyManager策略管理

5. 主合约集成
   - ModularGovernance主控制器
   - 模块组合管理
   - 统一接口暴露
   - 版本控制支持

这种设计体现了模块化治理的核心优势：
可维护性、可扩展性、可测试性、功能解耦。
*/