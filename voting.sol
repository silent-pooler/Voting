// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract Voting is Ownable, ReentrancyGuard {

    struct Voter {
        bool isRegistered;
        bool hasProposed;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus private votingStatus;

    mapping (address => Voter) public whitelist;
    
    Proposal[] public proposals;
    Proposal[] public winner_s;

    bool public isCounted;

    event VoterRegistered(address voterAddress);
    event VoterRemoved(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    modifier onlyWhitelisted(){
        require (whitelist[msg.sender].isRegistered == true, "you don't have the voting privilege");
        _;
    }

    function votersRegistration(address[] calldata voterAddresses) external onlyOwner{
        require(uint(votingStatus) == 0, "too late to add new voters");
        for(uint i = 0; i < voterAddresses.length ; i++){
            if(whitelist[voterAddresses[i]].isRegistered != true){
                whitelist[voterAddresses[i]].isRegistered = true;
                emit VoterRegistered(voterAddresses[i]);
            }
        }
    }

    function unregisterVoter(address voterAddress) external onlyOwner{
        require(whitelist[voterAddress].isRegistered == true, "voter isn't registered yet");
        require(uint(votingStatus) == 0, "too late to remove a voter");
        whitelist[voterAddress].isRegistered = false;
        emit VoterRemoved(voterAddress);
    }

    function openProposalsRegistration() external onlyOwner{
        require(uint(votingStatus) == 0, "wrong voting process");
        WorkflowStatus oldVotingStatus = WorkflowStatus(0);
        votingStatus = WorkflowStatus(1);
        Proposal memory abstentionProposal = Proposal("Abstention", 0);
        Proposal memory blankProposal = Proposal("Blank", 0);
        proposals.push(abstentionProposal);
        proposals.push(blankProposal);
        emit WorkflowStatusChange(oldVotingStatus, votingStatus);
        emit ProposalRegistered(0);
        emit ProposalRegistered(1);
    }

    function registerYourProposal(string calldata _proposal) external onlyWhitelisted nonReentrant{
        require(uint(votingStatus) == 1, "Proposals registration are not open");
        require(whitelist[msg.sender].hasProposed == false, "you already have made a proposition, only 1 per whitelisted account");
        whitelist[msg.sender].hasProposed = true;
        require(keccak256(abi.encodePacked(_proposal)) != keccak256(abi.encodePacked("")), "you can't propose an empty field");
        for(uint i = 0 ; i < proposals.length ; i ++){
            if(keccak256(abi.encodePacked(proposals[i].description)) == keccak256(abi.encodePacked(_proposal))){
                revert("Proposal already made by someone else and registered");
            }
        }
        Proposal memory memoryProposal = Proposal(_proposal, 0);
        proposals.push(memoryProposal);
        emit ProposalRegistered(proposals.length -1);
    }

    function closeProposalsRegistration() external onlyOwner{
        require(uint(votingStatus) == 1, "wrong voting process");
        WorkflowStatus oldVotingStatus = WorkflowStatus(1);
        votingStatus = WorkflowStatus(2);
        emit WorkflowStatusChange(oldVotingStatus, votingStatus);
    }

    function openVotingSession() external onlyOwner{
        require(uint(votingStatus) == 2, "wrong voting process");
        WorkflowStatus oldVotingStatus = WorkflowStatus(2);
        votingStatus = WorkflowStatus(3);
        emit WorkflowStatusChange(oldVotingStatus, votingStatus);
    }

    function vote(uint proposalId) external onlyWhitelisted nonReentrant{
        require(uint(votingStatus) == 3, "Voting session isn't open");
        require(proposalId < proposals.length, "This candidate isn't registered");
        require(whitelist[msg.sender].hasVoted == false, "You already have voted");
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = proposalId;
        proposals[proposalId].voteCount++;
        emit Voted(msg.sender, proposalId);
    }

    function closeVotingSession() external onlyOwner{
        require(uint(votingStatus) == 3, "Voting session isn't open");
        WorkflowStatus oldVotingStatus = WorkflowStatus(3);
        votingStatus = WorkflowStatus(4);
        emit WorkflowStatusChange(oldVotingStatus, votingStatus);
    }

    function counting() external onlyOwner nonReentrant{
        require(uint(votingStatus) == 4, "Voting process isn't over");
        require(isCounted == false, "Votes already tallied");
        Proposal[] memory votingResults = proposals;
        uint _highestCount;
        for (uint i = 0; i < votingResults.length; i++) {
            if (votingResults[i].voteCount > _highestCount) {
                _highestCount = votingResults[i].voteCount;
            }
        }
        isCounted = true;
        for(uint i = 0; i < votingResults.length; i++){
            if(votingResults[i].voteCount == _highestCount){
                winner_s.push(votingResults[i]);
            }
        }
        WorkflowStatus oldVotingStatus = WorkflowStatus(4);
        votingStatus = WorkflowStatus(5);
        emit WorkflowStatusChange(oldVotingStatus, votingStatus);
    }

    function getProposals() public view returns(string[] memory, uint[] memory){
        string[] memory allProposals = new string[](proposals.length);
        uint[] memory indexOfProposal = new uint[](proposals.length);
        for (uint i = 0; i < proposals.length; i++){
            allProposals[i] = proposals[i].description;
            indexOfProposal[i] = i;
        } 
        return(allProposals, indexOfProposal);
    }

    function getWinner() external view returns(string[] memory, uint[] memory){
        require(uint(votingStatus) == 5, "No winner(s) announced yet");
        string[] memory allwinner_s = new string[](winner_s.length);
        uint[] memory voteCountedFor = new uint[](winner_s.length);
        for (uint i = 0; i < winner_s.length; i++){
            allwinner_s[i] = winner_s[i].description;
            voteCountedFor[i] = winner_s[i].voteCount;
        } 
        return(allwinner_s, voteCountedFor);
    }

    function isWhitelisted(address voterAddress) public view returns(bool) {
        return whitelist[voterAddress].isRegistered;
    }

    function hasProposed(address voterAddress) public view returns (bool) {
        return whitelist[voterAddress].hasProposed;
    }

    function hasVoted(address voterAddress) public view returns (bool) {
        return whitelist[voterAddress].hasVoted;
    }

    function votedFor(address voterAddress) public view returns (uint) {
        require(whitelist[voterAddress].hasVoted == true, "user didn't vote");
        return whitelist[voterAddress].votedProposalId;
    }

    function getVotingStatus() public view returns (string memory){
        string memory _votingStatus;
        if(votingStatus == WorkflowStatus(0)){
            _votingStatus = "0 - Registering Voters";
        } else if (votingStatus == WorkflowStatus(1)){
            _votingStatus = "1 - Proposals Registration Started";
        } else if (votingStatus == WorkflowStatus(2)){
            _votingStatus = "2 - Proposals Registration Ended";
        } else if (votingStatus == WorkflowStatus(3)){
            _votingStatus = "3 - Voting Session Started";
        } else if (votingStatus == WorkflowStatus(4)){
            _votingStatus = "4 - Voting Session Ended";
        } else if (votingStatus == WorkflowStatus(5)){
            _votingStatus = "5 - Votes Tallied";
        }
        return _votingStatus;
    }
}