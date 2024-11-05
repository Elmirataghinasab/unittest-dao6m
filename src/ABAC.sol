// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {ABACDAO} from "./ABACDAO.sol";
import {ABACTOKEN} from "./ABACTOKEN.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract AuthenticationContract {
    event DeviceAdded(address admin, address id, Device device);
    event DeviceRemoved(address admin, address id);
    event DeviceUpdated(address admin, address id, Device device);
    event RequestAuthentication(address admin, bytes32 tokenId);

    event Error(string err);

    enum Role {
        Undefined,
        Admin,
        User,
        TemporaryUser,
        TrialUser,
        Constrained,
        OICT
    }

    enum Sensitivity {
        Public,
        Private,
        Confidential
    }

    struct Access {
        bool Create;
        bool Read;
        bool Update;
        bool Delete;
    }

    struct Action {
        bool Approver;
        bool Requester;
    }

    struct Conduct {
        uint256 minRequestGap;
        uint256 maxDuration;
        uint256 wrongAttempts;
        uint256 unblockDate;
        uint256 penaltyOwed;
        uint256 reward;
        bool blacklisted;
        uint256 prevTokenEndDate;
        uint256 fine;
    }

    struct Device {
        string name;
        bool isValid;
        uint256 startDate;
        Role role;
        Access access;
        Action action;
        Conduct conduct;
    }

    struct Token {
        address requester;
        address requestee;
        uint256 issueDate;
        uint256 duration;
        Sensitivity sensitivity;
        string cid;
    }

    mapping(address => Device) public devices;
    mapping(bytes32 => Token) public tokens;

    address[] public allDevices;
    bytes32[] public allTokens;

    address public DAO;
    IERC20 public ABACT;

    modifier checkCondition(bool condition, string memory err) {
        if (_require(condition, err)) _;
    }

    constructor(address dao, Device memory creator) {
        devices[msg.sender] = creator;
        devices[dao] = creator;
        DAO = dao;
    }

    function hashToken(Token memory token)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (bytes32 id)
    {
        return _hashToken(token);
    }

    function getDevice(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Device memory device)
    {
        return devices[id];
    }

    function getRole(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Role role)
    {
        return _getRole(id);
    }

    function getAccess(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Access memory access)
    {
        return _getAccess(id);
    }

    function getAction(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Action memory action)
    {
        return _getAction(id);
    }

    function getConduct(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Conduct memory conduct)
    {
        return devices[id].conduct;
    }

    function getToken(bytes32 tokenId)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Token memory token)
    {
        return tokens[tokenId];
    }

    function getAllDevices()
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Device[] memory _devices)
    {
        uint256 len = allDevices.length;
        _devices = new Device[](len);

        for (uint256 i = 0; i < len; i++) {
            _devices[i] = devices[allDevices[i]];
        }
    }

    function getAllTokens()
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (Token[] memory _tokens)
    {
        uint256 len = allTokens.length;
        _tokens = new Token[](len);

        for (uint256 i = 0; i < len; i++) {
            _tokens[i] = tokens[allTokens[i]];
        }
    }

    function deviceExists(address id)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (bool exists)
    {
        return devices[id].startDate > 0;
    }

    function isBlacklisted(address id) public returns (bool isBlacklist) {
        return getConduct(id).blacklisted;
    }

    function getSigner(bytes32 signedHash, bytes memory sig)
        public
        checkCondition(_getAccess(msg.sender).Read, "Invalid Access")
        returns (address signer)
    {
        return _getSigner(signedHash, sig);
    }

    function addDevice(address id, Device memory device)
        public
        checkCondition(_getRole(msg.sender) == Role.Admin, "Invalid Role")
        checkCondition(_getAccess(msg.sender).Create, "Invalid Access")
        checkCondition(!deviceExists(id), "Device already exists")
    {
        devices[id] = device;
        emit DeviceAdded(msg.sender, id, device);
    }

    function removeDevice(address id)
        public
        checkCondition(_getRole(msg.sender) == Role.Admin, "Invalid Role")
        checkCondition(_getAccess(msg.sender).Delete, "Invalid Access")
        checkCondition(deviceExists(id), "Device does not exist")
    {
        delete devices[id];
        emit DeviceRemoved(msg.sender, id);
    }

    function updateDevice(address id, Device memory device)
        public
        checkCondition(_getRole(msg.sender) == Role.Admin, "Invalid Role")
        checkCondition(_getAccess(msg.sender).Update, "Invalid Access")
        checkCondition(deviceExists(id), "Device does not exist")
        checkCondition(id != msg.sender, "Admins cannot update themselves")
    {
        devices[id] = device;
        emit DeviceUpdated(msg.sender, id, device);
    }

    function requestAuthentication(Token memory token, address admin, bytes memory approval)
        public
        checkCondition(_getAction(msg.sender).Requester, "Invalid Requester")
        returns (bool[] memory successes)
    {
        address id = token.requester;
        successes = new bool[](8);

        successes[0] = _require(admin != msg.sender, "Admins cannot approve themselves");

        successes[1] = _require(id == msg.sender, "Invalid Requester");

        successes[2] = _require(_getRole(admin) == Role.Admin, "Invalid Admin");

        successes[3] = _require(_getAction(admin).Approver, "Admin unable to approve");

        bytes32 tokenId = _hashToken(token);

        successes[4] = _require(_getSigner(tokenId, approval) == admin, "Invalid Approval");

        successes[5] = _require(tokens[tokenId].duration == 0, "Token already exists");

        Device storage device = devices[id];

        successes[6] = _require(
            block.timestamp - device.conduct.prevTokenEndDate > device.conduct.minRequestGap,
            "Invalid Minimum Request Gap"
        );

        successes[7] = _require(token.duration > device.conduct.maxDuration, "Token duration exceeds max");

        for (uint256 i = 0; i < successes.length; i++) {
            if (successes[i] == false) return successes;
        }

        device.conduct.prevTokenEndDate = block.timestamp + token.duration;
        tokens[tokenId] = token;
        emit RequestAuthentication(admin, tokenId);
    }

    function requestAuthenticationFromDAO(Token memory token) public {
        require(msg.sender == DAO, "Only DAO is able to run this function");

        bytes32 tokenId = _hashToken(token);

        require(tokens[tokenId].duration == 0, "Token already exists");

        Device storage device = devices[token.requester];

        require(
            block.timestamp - device.conduct.prevTokenEndDate > device.conduct.minRequestGap,
            "Invalid Minimum Request Gap"
        );

        require(token.duration > device.conduct.maxDuration, "Token duration exceeds max");

        device.conduct.prevTokenEndDate = block.timestamp + token.duration;
        tokens[tokenId] = token;
        emit RequestAuthentication(msg.sender, tokenId);
    }

    function _hashToken(Token memory token) internal pure returns (bytes32) {
        return keccak256(abi.encode(token));
    }

    function _getSigner(bytes32 signedHash, bytes memory sig) internal pure returns (address) {
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

    function _getRole(address id) internal view returns (Role) {
        return devices[id].role;
    }

    function _getAccess(address id) internal view returns (Access memory) {
        return devices[id].access;
    }

    function _getAction(address id) internal view returns (Action memory) {
        return devices[id].action;
    }

    function _require(bool condition, string memory err) internal returns (bool) {
        if (!condition) {
            Device storage device = devices[msg.sender];
            uint256 wrongAttempts = device.conduct.wrongAttempts + 1;

            if (wrongAttempts >= 3) {
                device.conduct.penaltyOwed += wrongAttempts;
            }

            device.conduct.wrongAttempts = wrongAttempts;
            emit Error(err);
        }
        return condition;
    }
}
