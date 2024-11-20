// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ABACDAO {
    event ProposalCreated(ProposalParams params);

    event ProposalExecuted(bool[] successes, bytes[] returnDatas);

    enum ProposalState {
        started,
        successful,
        failed,
        canceled
    }

    struct ProposalParams {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    struct ProposalCore {
        uint256 startDate;
        uint256 endDate;
        bytes32 parametersHash;
        ProposalState state;
        uint256 numberOfParticipants;
        int256 voteWeight;
    }

    address[] public entities;
    mapping(uint256 => ProposalCore) _proposals;
    mapping(address => mapping(uint256 => int256)) _votes;

    uint256 public proposalCounter = 0;

    string public name = "Access Control";
    string public version = "1";

    bytes32 public EIP712_TYPEHASH;
    bytes32 public NAME_TYPEHASH;
    bytes32 public VERSION_TYPEHASH;
    bytes32 public EIP712DOMAINHASH;

    bytes32 public VOTE_TYPEHASH;

    constructor() {
        EIP712_TYPEHASH = keccak256(
            abi.encodePacked("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        );

        NAME_TYPEHASH = hashString(name);
        VERSION_TYPEHASH = hashString(version);

        EIP712DOMAINHASH =
            keccak256(abi.encode(EIP712_TYPEHASH, NAME_TYPEHASH, VERSION_TYPEHASH, block.chainid, address(this)));

        VOTE_TYPEHASH = keccak256(abi.encodePacked("Vote(int256 vote)"));
    }

    receive() external payable {}

    function hashProposal(ProposalParams memory p) public pure returns (bytes32) {
        uint256 len = p.targets.length;

        require(len == p.values.length && len == p.calldatas.length, "Array mismatch");

        return keccak256(abi.encode(p.targets, p.values, p.calldatas, p.description));
    }

    function propose(ProposalParams memory params) public {
        proposalCounter++;
        ProposalCore storage proposal = _proposals[proposalCounter];

        require(_proposals[proposalCounter - 1].endDate < block.timestamp, "Previous proposal is still active");

        proposal.startDate = block.timestamp;
        proposal.endDate = block.timestamp + 8 hours;

        proposal.parametersHash = hashProposal(params);
        proposal.state = ProposalState.started;
        emit ProposalCreated(params);
    }

    function castVote(int256 vote) public {
        ProposalCore storage proposal = _proposals[proposalCounter];
        address voter = msg.sender;

        require(proposal.startDate + 4 hours > block.timestamp, "Voting is no longer active");

        require(_votes[voter][proposalCounter] == 0, "Voter has already voted");

        require(vote == 1 || vote == -1, "Invalid vote");

        _votes[voter][proposalCounter] = vote;

        proposal.numberOfParticipants++;
        proposal.voteWeight += vote;
    }

    function castVotesBySignature(address[] memory voters, int256[] memory votes, bytes[] memory signatures) public {
        ProposalCore storage proposal = _proposals[proposalCounter];

        require(proposal.startDate + 4 hours > block.timestamp, "Voting is no longer active");

        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            int256 vote = votes[i];

            require(_votes[voter][proposalCounter] == 0, "Voter has already voted");

            require(vote == 1 || vote == -1, "Invalid vote");

            _votes[voter][proposalCounter] = vote;

            proposal.numberOfParticipants++;
            proposal.voteWeight += vote;

            require(voter == getSigner(getHashStruct(vote), signatures[i]), "Invalid Voter Signature");
        }
    }

    function executeProposal(ProposalParams memory params) public returns (bool) {
        ProposalCore storage proposal = _proposals[proposalCounter];
        bytes32 proposalHash = hashProposal(params);

        require(proposalHash == proposal.parametersHash, "Proposal Params mismatch");

        require(
            proposal.startDate + 4 hours <= block.timestamp && proposal.endDate >= block.timestamp,
            "Execution is not active"
        );

        require(proposal.state == ProposalState.started, "Proposal has already been executed");

        if (proposal.voteWeight > 0) {
            executeParams(params);
            proposal.state = ProposalState.successful;
            return true;
        }

        proposal.state = ProposalState.failed;
        return false;
    }

    function executeParams(ProposalParams memory params) public {
        uint256 len = params.targets.length;

        bool[] memory successes = new bool[](len);
        bytes[] memory returnDatas = new bytes[](len);

        for (uint256 i = 0; i < len; ++i) {
            (successes[i], returnDatas[i]) = executeParam(params.targets[i], params.values[i], params.calldatas[i]);
        }

        emit ProposalExecuted(successes, returnDatas);
    }

    function executeParam(address target, uint256 amount, bytes memory calldatas) public returns (bool, bytes memory) {
        return target.call{value: amount}(calldatas);
    }

    function getProposal(uint256 proposalId) public view returns (ProposalCore memory) {
        return _proposals[proposalId];
    }

    function getVote(address voter, uint256 proposalId) public view returns (int256) {
        return _votes[voter][proposalId];
    }

    function getHashStruct(int256 vote) public view returns (bytes32) {
        return keccak256(abi.encode(VOTE_TYPEHASH, vote));
    }

    function getSigner(bytes32 hashStruct, bytes memory sig) public view returns (address) {
        return recoverSigner(getEIP712Hash(hashStruct), sig);
    }

    function getEIP712Hash(bytes32 hashStruct) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", EIP712DOMAINHASH, hashStruct));
    }

    function recoverSigner(bytes32 signedHash, bytes memory sig) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }

        return uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
            ? address(0)
            : ecrecover(signedHash, v, r, s);
    }

    function hashString(string memory str) public pure returns (bytes32) {
        return keccak256(bytes(str));
    }

    function getProposalCounter() public view returns (uint256) {
        return proposalCounter;
    }
}
