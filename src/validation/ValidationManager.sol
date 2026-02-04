// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../validation/ValidatorRegistry.sol";
import "../reputation/ReputationRegistry.sol";
import "../interfaces/IA2A.sol";

/**
 * @title ValidationManager
 * @dev Manages the validation process, challenges, and finalizations with A2A integration
 */
contract ValidationManager {
    struct Submission {
        uint256 agentId;
        address validator;
        uint256 submissionTime;
        bool finalized;
        bool challenged;
        uint256 workType;       // Type of work being validated
        uint256 workDifficulty; // Difficulty level of the work
    }

    ValidatorRegistry public validatorRegistry;
    ReputationRegistry public reputationRegistry;

    // A2A integration
    IA2A public a2aProtocol;

    mapping(uint256 => Submission) public submissions;
    uint256 public submissionCounter;

    uint256 public constant CHALLENGE_PERIOD = 1 days; // 1 day challenge period

    // Owner management
    address private _owner;

    event SubmissionCreated(uint256 indexed submissionId, uint256 agentId, address indexed validator);
    event SubmissionChallenged(uint256 indexed submissionId, address indexed challenger);
    event SubmissionFinalized(uint256 indexed submissionId, address indexed validator);
    event A2AProtocolSet(address indexed a2aProtocol);

    modifier onlyActiveValidator() {
        require(
            validatorRegistry.isActiveValidator(msg.sender),
            "ValidationManager: not an active validator"
        );
        // Also require that the validator has sufficient reputation
        require(
            reputationRegistry.hasSufficientReputation(getAgentIdForValidator(msg.sender)),
            "ValidationManager: validator has insufficient reputation"
        );
        _;
    }

    /**
     * @dev Initializes the ValidationManager with dependencies
     * @param _validatorRegistry Address of the ValidatorRegistry contract
     * @param _reputationRegistry Address of the ReputationRegistry contract
     */
    constructor(address _validatorRegistry, address _reputationRegistry) {
        validatorRegistry = ValidatorRegistry(_validatorRegistry);
        reputationRegistry = ReputationRegistry(_reputationRegistry);
        _owner = msg.sender;
    }

    /**
     * @dev Sets the A2A protocol contract for off-chain communication
     * @param _a2aProtocol Address of the A2A protocol contract
     */
    function setA2AProtocol(address _a2aProtocol) external {
        require(msg.sender == owner(), "ValidationManager: only owner can set A2A protocol");
        a2aProtocol = IA2A(_a2aProtocol);
        emit A2AProtocolSet(_a2aProtocol);
    }

    /**
     * @dev Submits a new validation with work type and difficulty
     * @param workType Type of work being validated
     * @param workDifficulty Difficulty level of the work (affects reputation reward)
     * @return submissionId The ID of the newly created submission
     */
    function submit(uint256 workType, uint256 workDifficulty) external onlyActiveValidator returns (uint256 submissionId) {
        uint256 agentId = getAgentIdForValidator(msg.sender); // Get agent ID associated with validator

        submissions[submissionCounter] = Submission({
            agentId: agentId,
            validator: msg.sender,
            submissionTime: block.timestamp,
            finalized: false,
            challenged: false,
            workType: workType,
            workDifficulty: workDifficulty
        });

        emit SubmissionCreated(submissionCounter, agentId, msg.sender);

        return submissionCounter++;
    }

    /**
     * @dev Challenges a submission during the challenge period
     * @param submissionId The ID of the submission to challenge
     */
    function challenge(uint256 submissionId) external {
        Submission storage submission = submissions[submissionId];
        require(!submission.finalized, "ValidationManager: submission already finalized");
        require(!submission.challenged, "ValidationManager: submission already challenged");
        require(
            block.timestamp < submission.submissionTime + CHALLENGE_PERIOD,
            "ValidationManager: challenge period expired"
        );

        submission.challenged = true;

        // Slash the validator's entire stake
        validatorRegistry.slash(submission.validator, validatorRegistry.stakeOf(submission.validator));

        // Also decrease the reputation of the challenged validator
        reputationRegistry.decreaseReputation(submission.agentId, 20); // Penalty for invalid submission

        emit SubmissionChallenged(submissionId, msg.sender);
    }

    /**
     * @dev Finalizes a submission after the challenge period
     * @param submissionId The ID of the submission to finalize
     */
    function finalize(uint256 submissionId) external {
        Submission storage submission = submissions[submissionId];
        require(!submission.finalized, "ValidationManager: submission already finalized");
        require(
            block.timestamp >= submission.submissionTime + CHALLENGE_PERIOD,
            "ValidationManager: challenge period not over"
        );
        require(!submission.challenged, "ValidationManager: submission was challenged");

        submission.finalized = true;

        // Reward the validator with reputation based on work performed
        reputationRegistry.performWork(submission.agentId, submission.workType, submission.workDifficulty);

        emit SubmissionFinalized(submissionId, submission.validator);
    }

    /**
     * @dev Checks if a submission can be challenged
     * @param submissionId The ID of the submission
     * @return Whether the submission can be challenged
     */
    function canBeChallenged(uint256 submissionId) external view returns (bool) {
        Submission memory submission = submissions[submissionId];
        return (
            !submission.finalized &&
            !submission.challenged &&
            block.timestamp < submission.submissionTime + CHALLENGE_PERIOD
        );
    }

    /**
     * @dev Checks if a submission can be finalized
     * @param submissionId The ID of the submission
     * @return Whether the submission can be finalized
     */
    function canBeFinalized(uint256 submissionId) external view returns (bool) {
        Submission memory submission = submissions[submissionId];
        return (
            !submission.finalized &&
            !submission.challenged &&
            block.timestamp >= submission.submissionTime + CHALLENGE_PERIOD
        );
    }

    /**
     * @dev Gets the agent ID associated with a validator
     * Uses the same calculation as ValidatorRegistry for consistency
     */
    function getAgentIdForValidator(address validator) internal view returns (uint256) {
        // Use the same calculation as ValidatorRegistry for consistency
        return uint256(keccak256(abi.encodePacked(validator))) % 1000000;
    }

    /**
     * @dev Returns the contract owner (needed for access control)
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }
}