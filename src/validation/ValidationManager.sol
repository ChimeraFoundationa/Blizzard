// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../validation/ValidatorRegistry.sol";
import "../reputation/ReputationRegistry.sol";

/**
 * @title ValidationManager
 * @dev Manages the validation process, challenges, and finalizations
 */
contract ValidationManager {
    struct Submission {
        uint256 agentId;
        address validator;
        uint256 submissionTime;
        bool finalized;
        bool challenged;
    }
    
    ValidatorRegistry public validatorRegistry;
    ReputationRegistry public reputationRegistry;
    
    mapping(uint256 => Submission) public submissions;
    uint256 public submissionCounter;
    
    uint256 public constant CHALLENGE_PERIOD = 1 days; // 1 day challenge period
    
    event SubmissionCreated(uint256 indexed submissionId, uint256 agentId, address indexed validator);
    event SubmissionChallenged(uint256 indexed submissionId, address indexed challenger);
    event SubmissionFinalized(uint256 indexed submissionId, address indexed validator);
    
    modifier onlyActiveValidator() {
        require(
            validatorRegistry.isActiveValidator(msg.sender),
            "ValidationManager: not an active validator"
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
    }
    
    /**
     * @dev Submits a new validation
     * @return submissionId The ID of the newly created submission
     */
    function submit() external onlyActiveValidator returns (uint256 submissionId) {
        uint256 agentId = submissionCounter; // Using counter as agentId for simplicity
        
        submissions[submissionCounter] = Submission({
            agentId: agentId,
            validator: msg.sender,
            submissionTime: block.timestamp,
            finalized: false,
            challenged: false
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
        
        // Reward the validator with reputation
        reputationRegistry.increaseReputation(submission.agentId, 10); // Fixed reward of 10 reputation points
        
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
}