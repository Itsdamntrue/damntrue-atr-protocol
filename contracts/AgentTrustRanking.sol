// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title AgentTrustRanking (ATR) Protocol
 * @notice On-chain trust metrics and machine-to-machine reputation oracle for autonomous AI agents.
 */
contract AgentTrustRanking is EIP712 {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    address public immutable protocolTreasury;
    address public owner;
    IERC20 public paymentToken;
    uint256 public queryFee;

    struct AgentMetrics {
        bool isRegistered;
        uint64 tasksCompleted;
        uint64 tasksFailed;
        uint64 disputesLost;
        uint64 totalLatencyMs;
        uint256 volumeSettled;
        uint256 lastActiveTimestamp;
    }

    struct Metric {
        address agent;
        bool success;
        uint64 latencyMs;
        uint256 volume;
        bool disputeLost;
    }

    mapping(address => AgentMetrics) public agentRegistry;
    mapping(address => bool) public isAuthorizedReporter;
    mapping(address => uint256) public reporterNonces;

    bytes32 private constant METRIC_TYPEHASH = keccak256(
        "Metric(address agent,bool success,uint64 latencyMs,uint256 volume,bool disputeLost)"
    );
    bytes32 private constant BATCH_TYPEHASH = keccak256(
        "BatchMetrics(Metric[] metrics,uint256 nonce)Metric(address agent,bool success,uint64 latencyMs,uint256 volume,bool disputeLost)"
    );

    event AgentRegistered(address indexed agent);
    event BatchProcessed(address indexed reporter, uint256 count);
    event ScoreQueried(address indexed caller, address indexed agent, uint256 score, uint256 feePaid);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner permitted");
        _;
    }

    constructor(
        address _treasury,
        uint256 _initialQueryFee,
        address _tokenAddress
    ) EIP712("DamnTrueATR", "1") {
        owner = msg.sender;
        protocolTreasury = _treasury;
        queryFee = _initialQueryFee;
        paymentToken = IERC20(_tokenAddress);
    }

    function registerAgent(address _agent) external {
        require(!agentRegistry[_agent].isRegistered, "Already registered");
        agentRegistry[_agent] = AgentMetrics({
            isRegistered: true,
            tasksCompleted: 0,
            tasksFailed: 0,
            disputesLost: 0,
            totalLatencyMs: 0,
            volumeSettled: 0,
            lastActiveTimestamp: block.timestamp
        });
        emit AgentRegistered(_agent);
    }

    function submitBatchMetrics(Metric[] calldata metrics, bytes calldata signature) external {
        address reporter = msg.sender;
        require(isAuthorizedReporter[reporter], "Unauthorized reporter");

        bytes32[] memory metricHashes = new bytes32[](metrics.length);
        for (uint256 i = 0; i < metrics.length; i++) {
            metricHashes[i] = keccak256(
                abi.encode(
                    METRIC_TYPEHASH,
                    metrics[i].agent,
                    metrics[i].success,
                    metrics[i].latencyMs,
                    metrics[i].volume,
                    metrics[i].disputeLost
                )
            );
        }

        bytes32 structHash = keccak256(
            abi.encode(
                BATCH_TYPEHASH,
                keccak256(abi.encodePacked(metricHashes)),
                reporterNonces[reporter]
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = digest.recover(signature);
        require(recoveredSigner == reporter, "Invalid signature");

        reporterNonces[reporter] += 1;

        for (uint256 i = 0; i < metrics.length; i++) {
            AgentMetrics storage m = agentRegistry[metrics[i].agent];
            if (!m.isRegistered) continue;

            if (metrics[i].success) {
                m.tasksCompleted += 1;
            } else {
                m.tasksFailed += 1;
            }

            if (metrics[i].disputeLost) {
                m.disputesLost += 1;
            }

            m.totalLatencyMs += metrics[i].latencyMs;
            m.volumeSettled += metrics[i].volume;
            m.lastActiveTimestamp = block.timestamp;
        }

        emit BatchProcessed(reporter, metrics.length);
    }

    function queryAgentScore(address _agent) external returns (uint256 score) {
        require(agentRegistry[_agent].isRegistered, "Target agent not registered");
        paymentToken.safeTransferFrom(msg.sender, protocolTreasury, queryFee);

        score = calculateTrustScore(_agent);
        emit ScoreQueried(msg.sender, _agent, score, queryFee);
        return score;
    }

    function calculateTrustScore(address _agent) public view returns (uint256) {
        AgentMetrics memory m = agentRegistry[_agent];
        uint64 totalTasks = m.tasksCompleted + m.tasksFailed;

        if (totalTasks == 0) return 500;

        uint256 successRate = (uint256(m.tasksCompleted) * 1000) / totalTasks;
        uint256 reliabilityScore = (successRate * 60) / 100;
        uint256 disputePenalty = uint256(m.disputesLost) * 50;
        uint256 activityBonus = totalTasks > 100 ? 400 : (uint256(totalTasks) * 4);

        uint256 rawScore = reliabilityScore + activityBonus;
        if (disputePenalty >= rawScore) return 0;

        uint256 finalScore = rawScore - disputePenalty;
        return finalScore > 1000 ? 1000 : finalScore;
    }

    function setReporter(address _reporter, bool _status) external onlyOwner {
        isAuthorizedReporter[_reporter] = _status;
    }

    function setQueryFee(uint256 _newFee) external onlyOwner {
        queryFee = _newFee;
    }
}
