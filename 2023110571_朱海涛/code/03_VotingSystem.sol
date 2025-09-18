// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VotingSystem - 基于博弈论和共识机制的投票系统
 * @author 朱海涛 (2023110571)
 * @notice 深入理解去中心化治理和投票理论的实现
 * @dev 基于拜占庭容错和共识算法理论的安全投票合约
 * 学习日期: 2024年10月16日
 */

/**
 * @dev 投票提案接口
 * 定义了提案的标准结构和操作
 */
interface IProposal {
    /// @notice 提案状态枚举
    enum ProposalState {
        Pending,    // 待开始
        Active,     // 进行中
        Succeeded,  // 通过
        Defeated,   // 失败
        Executed,   // 已执行
        Cancelled   // 已取消
    }
    
    /// @notice 获取提案状态
    /// @param proposalId 提案ID
    /// @return 提案当前状态
    function state(uint256 proposalId) external view returns (ProposalState);
    
    /// @notice 执行提案
    /// @param proposalId 提案ID
    function execute(uint256 proposalId) external;
}

/**
 * @dev 投票权重接口
 * 定义了投票权重的计算方法
 */
interface IVotingWeight {
    /// @notice 获取指定地址在指定区块的投票权重
    /// @param account 投票者地址
    /// @param blockNumber 区块号
    /// @return 投票权重
    function getVotes(address account, uint256 blockNumber) external view returns (uint256);
    
    /// @notice 获取当前投票权重
    /// @param account 投票者地址
    /// @return 当前投票权重
    function getVotes(address account) external view returns (uint256);
}

/**
 * @title 时间锁接口
 * @dev 用于延迟执行关键操作，增强安全性
 */
interface ITimelock {
    /// @notice 调度操作
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;
    
    /// @notice 执行操作
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external;
}

/**
 * @title VotingSystem - 去中心化治理投票系统
 * @dev 基于博弈论和机制设计理论的投票合约
 * 实现了安全、公平、透明的去中心化决策机制
 */
contract VotingSystem is IProposal {
    using SafeMath for uint256;
    
    // ============ 状态变量 ============
    
    /// @dev 提案结构体
    struct Proposal {
        uint256 id;                    // 提案ID
        address proposer;              // 提案者
        string title;                  // 提案标题
        string description;            // 提案描述
        address[] targets;             // 目标合约地址
        uint256[] values;              // 调用值
        bytes[] calldatas;             // 调用数据
        uint256 startBlock;            // 开始区块
        uint256 endBlock;              // 结束区块
        uint256 forVotes;              // 赞成票数
        uint256 againstVotes;          // 反对票数
        uint256 abstainVotes;          // 弃权票数
        bool executed;                 // 是否已执行
        bool cancelled;                // 是否已取消
        mapping(address => Receipt) receipts; // 投票记录
    }
    
    /// @dev 投票记录结构体
    struct Receipt {
        bool hasVoted;     // 是否已投票
        uint8 support;     // 投票选择 (0=反对, 1=赞成, 2=弃权)
        uint256 votes;     // 投票权重
        string reason;     // 投票理由
    }
    
    /// @dev 投票选择枚举
    enum VoteType {
        Against,    // 反对
        For,        // 赞成
        Abstain     // 弃权
    }
    
    // 合约参数
    string public constant name = "VotingSystem";
    string public constant version = "1.0";
    
    // 治理参数
    uint256 public votingDelay;        // 投票延迟（区块数）
    uint256 public votingPeriod;       // 投票周期（区块数）
    uint256 public proposalThreshold;  // 提案门槛
    uint256 public quorumNumerator;    // 法定人数分子
    uint256 public quorumDenominator;  // 法定人数分母
    
    // 状态变量
    uint256 private _proposalCounter;
    mapping(uint256 => Proposal) private _proposals;
    mapping(bytes32 => uint256) private _proposalIds;
    
    // 投票权重合约
    IVotingWeight public immutable token;
    
    // 时间锁合约
    ITimelock public timelock;
    
    // 管理员
    address public admin;
    
    // ============ 事件定义 ============
    
    /// @notice 提案创建事件
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    
    /// @notice 投票事件
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );
    
    /// @notice 提案执行事件
    event ProposalExecuted(uint256 proposalId);
    
    /// @notice 提案取消事件
    event ProposalCancelled(uint256 proposalId);
    
    /// @notice 参数更新事件
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    
    // ============ 自定义错误 ============
    
    error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);
    error GovernorAlreadyVoted(address voter);
    error GovernorDisabledDepositor();
    error GovernorInvalidVoteType();
    error GovernorNonexistentProposal(uint256 proposalId);
    error GovernorUnexpectedProposalState(uint256 proposalId, ProposalState current, bytes32 expectedStates);
    error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);
    error GovernorRestrictedProposer(address proposer);
    error GovernorInvalidVotingPeriod(uint256 votingPeriod);
    error GovernorInvalidVotingDelay(uint256 votingDelay);
    error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);
    
    // ============ 修饰符 ============
    
    /// @dev 仅管理员修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "VotingSystem: caller is not admin");
        _;
    }
    
    /// @dev 仅治理合约修饰符
    modifier onlyGovernance() {
        require(msg.sender == address(this), "VotingSystem: caller is not governance");
        _;
    }
    
    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数
     * @param _token 投票权重代币合约
     * @param _votingDelay 投票延迟
     * @param _votingPeriod 投票周期
     * @param _proposalThreshold 提案门槛
     * @param _quorumNumerator 法定人数分子
     * @param _quorumDenominator 法定人数分母
     */
    constructor(
        IVotingWeight _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumNumerator,
        uint256 _quorumDenominator
    ) {
        // 参数验证
        require(address(_token) != address(0), "VotingSystem: invalid token address");
        require(_votingPeriod > 0, "VotingSystem: invalid voting period");
        require(_quorumNumerator <= _quorumDenominator, "VotingSystem: invalid quorum fraction");
        require(_quorumDenominator > 0, "VotingSystem: quorum denominator cannot be zero");
        
        token = _token;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumNumerator = _quorumNumerator;
        quorumDenominator = _quorumDenominator;
        admin = msg.sender;
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @dev 创建提案
     * @param targets 目标合约地址数组
     * @param values 调用值数组
     * @param calldatas 调用数据数组
     * @param description 提案描述
     * @return 提案ID
     * 
     * @notice 基于机制设计理论，确保提案创建的公平性和有效性
     * 前置条件：
     * - 提案者必须拥有足够的投票权重
     * - 参数数组长度必须一致
     * - 描述不能为空
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        // 参数验证
        if (targets.length != values.length || targets.length != calldatas.length || targets.length == 0) {
            revert GovernorInvalidProposalLength(targets.length, calldatas.length, values.length);
        }
        
        // 检查提案者权重
        uint256 proposerVotes = getVotes(msg.sender, block.number - 1);
        if (proposerVotes < getProposalThreshold()) {
            revert GovernorInsufficientProposerVotes(msg.sender, proposerVotes, getProposalThreshold());
        }
        
        // 生成提案ID
        uint256 proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        
        // 检查提案是否已存在
        if (_proposals[proposalId].id != 0) {
            revert GovernorNonexistentProposal(proposalId);
        }
        
        // 计算投票时间
        uint256 snapshot = block.number + votingDelay;
        uint256 deadline = snapshot + votingPeriod;
        
        // 创建提案
        Proposal storage proposal = _proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.startBlock = snapshot;
        proposal.endBlock = deadline;
        
        // 更新计数器
        _proposalCounter++;
        
        // 发出事件
        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            snapshot,
            deadline,
            description
        );
        
        return proposalId;
    }
    
    /**
     * @dev 投票函数
     * @param proposalId 提案ID
     * @param support 投票选择
     * @param reason 投票理由
     * @return 投票权重
     * 
     * @notice 基于博弈论原理，实现策略性投票的防护机制
     * 前置条件：
     * - 提案必须处于活跃状态
     * - 投票者尚未投票
     * - 投票选择必须有效
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256) {
        return _castVote(proposalId, msg.sender, support, reason);
    }
    
    /**
     * @dev 简化投票函数
     * @param proposalId 提案ID
     * @param support 投票选择
     * @return 投票权重
     */
    function castVote(uint256 proposalId, uint8 support) public virtual returns (uint256) {
        return _castVote(proposalId, msg.sender, support, "");
    }
    
    /**
     * @dev 执行提案
     * @param proposalId 提案ID
     * 
     * @notice 基于共识机制理论，确保只有通过的提案才能执行
     * 前置条件：
     * - 提案必须处于成功状态
     * - 提案尚未执行
     */
    function execute(uint256 proposalId) public virtual override {
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Succeeded) {
            revert GovernorUnexpectedProposalState(
                proposalId,
                currentState,
                _encodeStateBitmap(ProposalState.Succeeded)
            );
        }
        
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;
        
        // 执行提案中的所有操作
        _executeOperations(proposalId, proposal.targets, proposal.values, proposal.calldatas);
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev 取消提案
     * @param proposalId 提案ID
     * 
     * @notice 只有提案者或管理员可以取消提案
     */
    function cancel(uint256 proposalId) public virtual {
        Proposal storage proposal = _proposals[proposalId];
        require(proposal.id != 0, "VotingSystem: proposal does not exist");
        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "VotingSystem: only proposer or admin can cancel"
        );
        
        ProposalState currentState = state(proposalId);
        require(
            currentState == ProposalState.Pending || currentState == ProposalState.Active,
            "VotingSystem: cannot cancel executed proposal"
        );
        
        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }
    
    // ============ 查询函数 ============
    
    /**
     * @dev 获取提案状态
     * @param proposalId 提案ID
     * @return 提案状态
     * 
     * @notice 基于状态机理论实现的状态转换逻辑
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        Proposal storage proposal = _proposals[proposalId];
        
        // 检查提案是否存在
        if (proposal.id == 0) {
            revert GovernorNonexistentProposal(proposalId);
        }
        
        // 检查是否已取消
        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }
        
        // 检查是否已执行
        if (proposal.executed) {
            return ProposalState.Executed;
        }
        
        // 检查投票是否开始
        if (block.number < proposal.startBlock) {
            return ProposalState.Pending;
        }
        
        // 检查投票是否结束
        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }
        
        // 检查是否达到法定人数和多数票
        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }
    
    /**
     * @dev 获取提案详情
     * @param proposalId 提案ID
     * @return 提案的各项信息
     */
    function getProposal(uint256 proposalId) public view returns (
        address proposer,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = _proposals[proposalId];
        return (
            proposal.proposer,
            proposal.startBlock,
            proposal.endBlock,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.cancelled
        );
    }
    
    /**
     * @dev 获取投票记录
     * @param proposalId 提案ID
     * @param voter 投票者地址
     * @return 投票记录
     */
    function getReceipt(uint256 proposalId, address voter) public view returns (
        bool hasVoted,
        uint8 support,
        uint256 votes,
        string memory reason
    ) {
        Receipt storage receipt = _proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes, receipt.reason);
    }
    
    /**
     * @dev 获取法定人数
     * @param blockNumber 区块号
     * @return 法定人数
     */
    function quorum(uint256 blockNumber) public view virtual returns (uint256) {
        return (token.getVotes(address(0), blockNumber) * quorumNumerator) / quorumDenominator;
    }
    
    /**
     * @dev 获取提案门槛
     * @return 提案门槛
     */
    function getProposalThreshold() public view virtual returns (uint256) {
        return proposalThreshold;
    }
    
    /**
     * @dev 获取投票权重
     * @param account 账户地址
     * @param blockNumber 区块号
     * @return 投票权重
     */
    function getVotes(address account, uint256 blockNumber) public view virtual returns (uint256) {
        return token.getVotes(account, blockNumber);
    }
    
    // ============ 内部函数 ============
    
    /**
     * @dev 内部投票函数
     * @param proposalId 提案ID
     * @param voter 投票者
     * @param support 投票选择
     * @param reason 投票理由
     * @return 投票权重
     */
    function _castVote(
        uint256 proposalId,
        address voter,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        // 检查提案状态
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Active) {
            revert GovernorUnexpectedProposalState(
                proposalId,
                currentState,
                _encodeStateBitmap(ProposalState.Active)
            );
        }
        
        // 检查投票选择
        if (support > uint8(VoteType.Abstain)) {
            revert GovernorInvalidVoteType();
        }
        
        Proposal storage proposal = _proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        
        // 检查是否已投票
        if (receipt.hasVoted) {
            revert GovernorAlreadyVoted(voter);
        }
        
        // 获取投票权重
        uint256 weight = getVotes(voter, proposal.startBlock);
        
        // 记录投票
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = weight;
        receipt.reason = reason;
        
        // 更新投票统计
        if (support == uint8(VoteType.Against)) {
            proposal.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }
        
        emit VoteCast(voter, proposalId, support, weight, reason);
        
        return weight;
    }
    
    /**
     * @dev 检查是否达到法定人数
     * @param proposalId 提案ID
     * @return 是否达到法定人数
     */
    function _quorumReached(uint256 proposalId) internal view virtual returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        return totalVotes >= quorum(proposal.startBlock);
    }
    
    /**
     * @dev 检查投票是否成功
     * @param proposalId 提案ID
     * @return 投票是否成功
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }
    
    /**
     * @dev 执行提案操作
     * @param proposalId 提案ID
     * @param targets 目标地址
     * @param values 调用值
     * @param calldatas 调用数据
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal virtual {
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            if (!success) {
                if (returndata.length > 0) {
                    assembly {
                        let returndata_size := mload(returndata)
                        revert(add(32, returndata), returndata_size)
                    }
                } else {
                    revert("VotingSystem: execution failed");
                }
            }
        }
    }
    
    /**
     * @dev 生成提案哈希
     * @param targets 目标地址
     * @param values 调用值
     * @param calldatas 调用数据
     * @param descriptionHash 描述哈希
     * @return 提案ID
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }
    
    /**
     * @dev 编码状态位图
     * @param proposalState 提案状态
     * @return 状态位图
     */
    function _encodeStateBitmap(ProposalState proposalState) internal pure returns (bytes32) {
        return bytes32(1 << uint8(proposalState));
    }
    
    // ============ 管理函数 ============
    
    /**
     * @dev 设置投票延迟
     * @param newVotingDelay 新的投票延迟
     */
    function setVotingDelay(uint256 newVotingDelay) public virtual onlyGovernance {
        emit VotingDelaySet(votingDelay, newVotingDelay);
        votingDelay = newVotingDelay;
    }
    
    /**
     * @dev 设置投票周期
     * @param newVotingPeriod 新的投票周期
     */
    function setVotingPeriod(uint256 newVotingPeriod) public virtual onlyGovernance {
        if (newVotingPeriod == 0) {
            revert GovernorInvalidVotingPeriod(newVotingPeriod);
        }
        emit VotingPeriodSet(votingPeriod, newVotingPeriod);
        votingPeriod = newVotingPeriod;
    }
    
    /**
     * @dev 设置提案门槛
     * @param newProposalThreshold 新的提案门槛
     */
    function setProposalThreshold(uint256 newProposalThreshold) public virtual onlyGovernance {
        emit ProposalThresholdSet(proposalThreshold, newProposalThreshold);
        proposalThreshold = newProposalThreshold;
    }
    
    /**
     * @dev 更新法定人数分子
     * @param newQuorumNumerator 新的法定人数分子
     */
    function updateQuorumNumerator(uint256 newQuorumNumerator) public virtual onlyGovernance {
        if (newQuorumNumerator > quorumDenominator) {
            revert GovernorInvalidQuorumFraction(newQuorumNumerator, quorumDenominator);
        }
        emit QuorumNumeratorUpdated(quorumNumerator, newQuorumNumerator);
        quorumNumerator = newQuorumNumerator;
    }
    
    /**
     * @dev 设置时间锁
     * @param newTimelock 新的时间锁地址
     */
    function setTimelock(address newTimelock) public virtual onlyAdmin {
        timelock = ITimelock(newTimelock);
    }
    
    /**
     * @dev 转移管理权
     * @param newAdmin 新管理员地址
     */
    function transferAdmin(address newAdmin) public virtual onlyAdmin {
        require(newAdmin != address(0), "VotingSystem: new admin is zero address");
        admin = newAdmin;
    }
}

/**
 * @title SafeMath库
 * @dev 安全数学运算库
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

/**
 * 个人学习笔记 - 朱海涛
 * 
 * 去中心化治理的理论基础：
 * 1. 博弈论应用：分析投票者的策略行为和激励机制
 * 2. 机制设计：设计激励相容的投票规则
 * 3. 社会选择理论：Arrow不可能定理在区块链治理中的体现
 * 4. 拜占庭容错：在恶意节点存在下达成共识
 * 
 * 投票系统的数学模型：
 * - 法定人数：Q = (Total Supply × Numerator) / Denominator
 * - 通过条件：For Votes > Against Votes AND Total Votes ≥ Q
 * - 投票权重：基于代币持有量的平方根或线性函数
 * - 时间衰减：投票权重随时间衰减，防止长期垄断
 * 
 * 共识机制的理论分析：
 * - 安全性(Safety)：不会产生冲突的决策
 * - 活跃性(Liveness)：系统能够持续产生决策
 * - 容错性(Fault Tolerance)：能够容忍一定比例的恶意行为
 * - 终止性(Termination)：投票过程能够在有限时间内结束
 * 
 * 治理攻击的防护机制：
 * - 时间锁：延迟执行关键操作
 * - 提案门槛：防止垃圾提案
 * - 投票延迟：防止闪电贷攻击
 * - 法定人数：确保足够的参与度
 * 
 * 状态机理论的应用：
 * - 提案生命周期：Pending → Active → Succeeded/Defeated → Executed
 * - 状态转换条件：基于时间、投票结果和执行状态
 * - 不变量维护：确保状态转换的一致性和正确性
 * 
 * 经济学原理的体现：
 * - 激励相容：投票者的最优策略与系统目标一致
 * - 搭便车问题：通过代币激励解决参与不足
 * - 信息聚合：通过投票机制聚合分散的信息
 * - 委托代理：通过代理投票解决专业性问题
 * 
 * 学习心得：
 * - 深入理解了去中心化治理的理论基础和实现原理
 * - 掌握了博弈论和机制设计在区块链中的应用
 * - 学会了如何设计安全可靠的投票系统
 * - 认识到治理机制对区块链生态发展的重要性
 * - 理解了数学理论在实际系统设计中的指导作用
 */