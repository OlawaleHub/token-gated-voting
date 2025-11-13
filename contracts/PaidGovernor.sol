// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IVoteToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}
contract PaidGovernor is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    AccessControl,
    Pausable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IVoteToken public immutable voteToken;
    uint256 public voteCost;               // Fixed cost in VOTE tokens per vote
    bool public freeVotingEnabled;         // Allow free vote if holding tokens
    address public treasury;               // Where paid tokens go
    bool public burnInsteadOfTreasury;     // Burn paid tokens?

    // Refund tracking
    mapping(uint256 => mapping(address => bool)) public hasPaid;
    mapping(uint256 => mapping(address => bool)) public hasRefunded;

    event VoteCostChanged(uint256 newCost);
    event VoteCastWithPayment(uint256 indexed proposalId, address indexed voter, uint256 amountPaid);
    event RefundClaimed(uint256 indexed proposalId, address indexed voter);

    constructor(
        IVoteToken _token,
        uint256 _voteCost,
        address _treasury,
        TimelockController _timelock
    )

    Governor("PaidGovernor")
        GovernorSettings(1, /* voting delay */ 7200, /* voting period */ 50400, 0)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {
        voteToken = _token;
        voteCost = _voteCost;
        treasury = _treasury;
        burnInsteadOfTreasury = false;
        freeVotingEnabled = true;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ---------- ADMIN FUNCTIONS ----------
    function setVoteCost(uint256 _newCost) external onlyRole(ADMIN_ROLE) {
        voteCost = _newCost;
        emit VoteCostChanged(_newCost);
    }

    function toggleFreeVoting(bool enabled) external onlyRole(ADMIN_ROLE) {
        freeVotingEnabled = enabled;
    }

    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        treasury = _treasury;
    }

    function setBurn(bool burn) external onlyRole(ADMIN_ROLE) {
        burnInsteadOfTreasury = burn;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ---------- VOTING WITH PAYMENT ----------
    function castVoteWithPayment(uint256 proposalId, uint8 support) external whenNotPaused returns (uint256) {
        require(voteCost > 0, "Vote cost zero");
        address voter = msg.sender;

        require(!hasPaid[proposalId][voter], "Already paid");
        hasPaid[proposalId][voter] = true;

        require(
            voteToken.transferFrom(voter, burnInsteadOfTreasury ? address(0xdead) : treasury, voteCost),
            "Payment failed"
        );

        emit VoteCastWithPayment(proposalId, voter, voteCost);

        // Always give 1 vote weight for payment (or use token balance if free enabled)
        uint256 weight = freeVotingEnabled ? getVotes(voter, block.number - 1) : 1;
        if (weight == 0) weight = 1;

        return _countVote(proposalId, voter, support, weight, "");
    }

    // ---------- STANDARD OVERRIDES ----------
    function castVote(uint256 proposalId, uint8 support) public override whenNotPaused returns (uint256) {
        if (freeVotingEnabled) {
            return super.castVote(proposalId, support);
        } else {
            revert("Free voting disabled - use castVoteWithPayment");
        }
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) public override returns (uint256) {
        if (freeVotingEnabled) {
            return super.castVoteWithReason(proposalId, support, reason);
        } else {
            revert("Free voting disabled");
        }
    }

    // ---------- REFUND ON CANCEL ----------
    function cancelProposal(uint256 proposalId) external onlyRole(ADMIN_ROLE) {
        ProposalState state = state(proposalId);
        require(state == ProposalState.Active || state == ProposalState.Pending, "Cannot cancel");
        _cancel(proposalId);
    }

    function claimRefund(uint256 proposalId) external whenNotPaused {
        require(state(proposalId) == ProposalState.Canceled, "Not canceled");
        require(hasPaid[proposalId][msg.sender], "Did not pay");
        require(!hasRefunded[proposalId][msg.sender], "Already refunded");

        hasRefunded[proposalId][msg.sender] = true;
        require(voteToken.transfer(msg.sender, voteCost), "Refund failed");
        emit RefundClaimed(proposalId, msg.sender);
    }

    // ---------- REQUIRED OVERRIDES ----------
    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
    
