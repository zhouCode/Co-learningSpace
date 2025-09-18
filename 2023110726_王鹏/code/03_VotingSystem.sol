// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title VotingSystem - 简洁版投票系统
 * @author 王鹏 (2023110726)
 * @notice 实现基础投票功能的简洁合约
 */
contract VotingSystem {
    struct Proposal {
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool active;
    }
    
    address public owner;
    uint256 public proposalCount;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    event ProposalCreated(uint256 indexed proposalId, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool vote);
    event ProposalClosed(uint256 indexed proposalId);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    function createProposal(string memory description) public onlyOwner {
        proposals[proposalCount] = Proposal({
            description: description,
            yesVotes: 0,
            noVotes: 0,
            active: true
        });
        
        emit ProposalCreated(proposalCount, description);
        proposalCount++;
    }
    
    function vote(uint256 proposalId, bool support) public {
        require(proposalId < proposalCount, "Invalid proposal");
        require(proposals[proposalId].active, "Proposal not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].yesVotes++;
        } else {
            proposals[proposalId].noVotes++;
        }
        
        emit VoteCast(proposalId, msg.sender, support);
    }
    
    function closeProposal(uint256 proposalId) public onlyOwner {
        require(proposalId < proposalCount, "Invalid proposal");
        require(proposals[proposalId].active, "Already closed");
        
        proposals[proposalId].active = false;
        emit ProposalClosed(proposalId);
    }
    
    function getProposal(uint256 proposalId) public view returns (
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        bool active
    ) {
        require(proposalId < proposalCount, "Invalid proposal");
        Proposal memory proposal = proposals[proposalId];
        return (proposal.description, proposal.yesVotes, proposal.noVotes, proposal.active);
    }
}

/*
=== 王鹏的学习笔记 ===

简洁投票系统设计思路：
1. 核心功能导向 - 创建提案、投票、关闭提案
2. 简单的权限模型 - 只有owner和voter两种角色
3. 基础的状态管理 - 使用简单的mapping和struct
4. 直观的数据结构 - Proposal结构体包含必要信息

简洁版特点：
- 一人一票的简单投票机制
- 二选一的投票选项（支持/反对）
- 基础的重复投票防护
- 简单的提案生命周期管理

省略的复杂功能：
- 权重投票
- 多选投票
- 时间限制
- 法定人数要求
- 委托投票

这种简洁设计的优势：
1. 逻辑清晰易懂
2. 代码量少，bug风险低
3. gas消耗可预测
4. 易于测试和验证

适用场景：
- 小型组织决策
- 简单的社区投票
- 学习和原型开发
- 快速MVP验证

简洁编程的核心：
"简洁是可靠性的前提" - 代码越简单，出错的可能性越小
*/