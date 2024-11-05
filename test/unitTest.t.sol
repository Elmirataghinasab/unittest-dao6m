// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ABACScript} from "../script/deploy.s.sol";
import {AuthenticationContract} from "../src/ABAC.sol";
import {ABACTOKEN} from "../src/ABACTOKEN.sol";
import {ABACDAO} from "../src/ABACDAO.sol";

contract ABAC is Test {
    ABACScript deploy;
    ABACTOKEN token;
    ABACDAO dao;
    AuthenticationContract auth;
    address public user = address(1);
    address public proposer = address(this);
    address public voter = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 public voterPrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address public voter2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    uint256 public voter2PrivateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

    function setUp() public {
        deploy = new ABACScript();
        token = deploy.runABACTOKEN(address(this), 100000);
        dao = deploy.runABACDaO();
        auth = deploy.runAuthenticationContract(address(dao));
    }

    ///Tests of the token///

    function testInitialValue() public view {
        uint256 supply = token.totalSupply();
        assertEq(supply, 100000);
    }

    function testMinting() public {
        token.mint(user, 500);
        assertEq(token.balanceOf(user), 500);
    }

    function testTransfer() public {
        token.transfer(user, 200);
        assertEq(token.balanceOf(user), 200);
        assertEq(token.balanceOf(address(this)), 99800);
    }

    function testApproveAllowance() public {
        token.approve(user, 300);
        assertEq(token.allowance(address(this), user), 300);
    }

    function testTransferFrom() public {
        token.approve(user, 300);
        vm.prank(user);
        token.transferFrom(address(this), user, 300);
        assertEq(token.balanceOf(user), 300);
        assertEq(token.balanceOf(address(this)), 99700);
    }

    function testOfDecimal() public view {
        //the contract has not gave a decimal point to the token
        assertEq(token.decimals(), 0);
    }

    ///Dao tests///

    function testRecive() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success,) = address(dao).call{value: 1 ether}("");

        assertEq(address(dao).balance, 1 ether);
        assertTrue(success);
    }

    function testProposalCreation() public {
        ABACDAO.ProposalParams memory params;
        params.targets = new address[](1);
        params.values = new uint256[](1);
        params.calldatas = new bytes[](1);
        params.description = "Test Proposal";

        params.targets[0] = address(0);
        params.values[0] = 0;
        params.calldatas[0] = new bytes(0);

        dao.propose(params);
        ABACDAO.ProposalCore memory proposal = dao.getProposal(1);

        assertEq(uint256(proposal.state), uint256(ABACDAO.ProposalState.started));
        assertGt(proposal.endDate, proposal.startDate);
        assertEq(dao.getProposalCounter(), 1);
    }

    function testVoteOnProposal() public {
        ABACDAO.ProposalParams memory params;

        params.description = "Vote Test Proposal";
        params.targets = new address[](1);
        params.values = new uint256[](1);
        params.calldatas = new bytes[](1);
        params.targets[0] = address(0);
        params.values[0] = 0;
        params.calldatas[0] = new bytes(0);

        dao.propose(params);

        vm.prank(voter);
        dao.castVote(1);

        ABACDAO.ProposalCore memory proposal = dao.getProposal(1);
        assertEq(proposal.numberOfParticipants, 1);
        assertEq(proposal.voteWeight, 1);
        assert(proposal.startDate + 4 hours > block.timestamp);
    }

    function testMultipleVotes() public {
        ABACDAO.ProposalParams memory params;
        params.targets = new address[](2);
        params.values = new uint256[](2);
        params.calldatas = new bytes[](2);
        params.description = "Multi-vote Proposal";

        params.targets[0] = address(0);
        params.values[0] = 0;
        params.calldatas[0] = new bytes(0);

        dao.propose(params);

        vm.prank(voter);
        dao.castVote(1);

        vm.prank(voter2);
        dao.castVote(1);

        ABACDAO.ProposalCore memory proposal = dao.getProposal(1);
        assertEq(proposal.numberOfParticipants, 2);
        assertEq(proposal.voteWeight, 2);
    }

    function testCastVotesBySignature() public {
        ABACDAO.ProposalParams memory params;

        params.description = "Vote By Signature Test Proposal";
        params.targets = new address[](2);
        params.values = new uint256[](2);
        params.calldatas = new bytes[](2);
        params.targets[0] = address(0);
        params.values[0] = 0;
        params.calldatas[0] = new bytes(0);

        dao.propose(params);
        uint256 proposalId = 1;

        int256[] memory votes = new int256[](2);
        votes[0] = 1;
        votes[1] = 1;

        address[] memory voters = new address[](2);
        voters[0] = voter;
        voters[1] = voter2;

        bytes[] memory signatures = new bytes[](2);

        signatures[0] = signVote(voterPrivateKey, votes[0]);

        signatures[1] = signVote(voter2PrivateKey, votes[1]);

        dao.castVotesBySignature(voters, votes, signatures);

        ABACDAO.ProposalCore memory proposal = dao.getProposal(1);

        console.log(dao.getVote(voter, proposalId));
        assertEq(proposal.numberOfParticipants, 2);
        assertEq(proposal.voteWeight, 2);
        assertEq(dao.getVote(voter, proposalId), votes[0]);
        assertEq(dao.getVote(voter2, proposalId), votes[1]);
    }

    function signVote(uint256 privateKey, int256 vote) internal view returns (bytes memory) {
        bytes32 voteHashStruct = dao.getHashStruct(vote);
        bytes32 eip712Hash = dao.getEIP712Hash(voteHashStruct);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, eip712Hash);
        return abi.encodePacked(r, s, v);
    }

    ///ABAC AUth test///

    function testAddRemoveDevice() public {
        AuthenticationContract.Device memory newDevice = AuthenticationContract.Device({
            name: "User Device",
            isValid: true,
            startDate: block.timestamp,
            role: AuthenticationContract.Role.User,
            access: AuthenticationContract.Access(true, true, false, false),
            action: AuthenticationContract.Action(false, true),
            conduct: AuthenticationContract.Conduct(1 hours, 2 hours, 0, 0, 0, 50, false, 0, 0)
        });

        auth.addDevice(user, newDevice);
        AuthenticationContract.Device memory device = auth.getDevice(user);
        assertEq(device.isValid, true);

        auth.removeDevice(user);
        bool exists = auth.deviceExists(user);
        assertFalse(exists);
    }

    function testRequestAuthenticationAndrequestAuthenticationFromDAO() public {
        AuthenticationContract.Token memory tokenData = AuthenticationContract.Token({
            requester: user,
            requestee: proposer,
            issueDate: block.timestamp,
            duration: 1 hours,
            sensitivity: AuthenticationContract.Sensitivity.Private,
            cid: "abc123"
        });

        bytes memory approval = hex"00";
        vm.prank(msg.sender);
        bool[] memory results = auth.requestAuthentication(tokenData, proposer, approval);

        assertTrue(results[0]);

        vm.prank(address(dao));
        auth.requestAuthenticationFromDAO(tokenData);
        bytes32 tokenId = keccak256(abi.encode(tokenData));
        AuthenticationContract.Token memory storedToken = auth.getToken(tokenId);
        assertEq(storedToken.requester, tokenData.requester);
        assertEq(storedToken.requestee, tokenData.requestee);
        assertEq(storedToken.issueDate, tokenData.issueDate);
        assertEq(storedToken.duration, tokenData.duration);
        assertEq(uint256(storedToken.sensitivity), uint256(tokenData.sensitivity));
        assertEq(storedToken.cid, tokenData.cid);
    }

    function testGetRole() public {
        AuthenticationContract.Role role = auth.getRole(proposer);
        assertEq(uint256(role), uint256(AuthenticationContract.Role.Admin));
    }

    function testGetAccessAndGetConduct() public {
        AuthenticationContract.Device memory newDevice = AuthenticationContract.Device({
            name: "User Device",
            isValid: true,
            startDate: block.timestamp,
            role: AuthenticationContract.Role.User,
            access: AuthenticationContract.Access(true, true, false, false),
            action: AuthenticationContract.Action(false, true),
            conduct: AuthenticationContract.Conduct(1 hours, 2 hours, 0, 0, 0, 50, false, 0, 0)
        });

        vm.startPrank(proposer);

        auth.addDevice(user, newDevice);
        AuthenticationContract.Access memory access = auth.getAccess(user);
        assertTrue(access.Read);

        vm.stopPrank();

        vm.startPrank(proposer);

        auth.addDevice(user, newDevice);
        AuthenticationContract.Conduct memory conduct = auth.getConduct(user);
        assertEq(conduct.minRequestGap, 3600);

        vm.stopPrank();
    }
}
