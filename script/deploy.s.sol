//SPDX-License-Identifier:MIT
pragma solidity ^0.8.2;

import {Script, console} from "forge-std/Script.sol";
import {ABACTOKEN} from "../src/ABACTOKEN.sol";
import {AuthenticationContract} from "../src/ABAC.sol";
import {ABACDAO} from "../src/ABACDAO.sol";

contract ABACScript is Script {
    function runABACTOKEN(address founder, uint256 initialSupply) external returns (ABACTOKEN) {
        vm.startBroadcast();
        ABACTOKEN token = new ABACTOKEN();
        token.mint(founder, initialSupply);
        vm.stopBroadcast();

        return token;
    }

    function runABACDaO() external returns (ABACDAO) {
        vm.startBroadcast();
        ABACDAO dao = new ABACDAO();
        vm.stopBroadcast();

        return dao;
    }

    function runAuthenticationContract(address dao) external returns (AuthenticationContract) {
        vm.startBroadcast();

        AuthenticationContract.Device memory device;

        device.name = "Initial Device";
        device.isValid = true;
        device.startDate = block.timestamp;
        device.role = AuthenticationContract.Role.Admin;

        device.access = AuthenticationContract.Access({Create: true, Read: true, Update: true, Delete: true});

        device.action = AuthenticationContract.Action({Approver: true, Requester: true});

        device.conduct = AuthenticationContract.Conduct({
            minRequestGap: 1 days,
            maxDuration: 7 days,
            wrongAttempts: 0,
            unblockDate: block.timestamp,
            penaltyOwed: 0,
            reward: 0,
            blacklisted: false,
            prevTokenEndDate: 0,
            fine: 0
        });

        AuthenticationContract auth = new AuthenticationContract(dao, device);
        auth.addDevice(msg.sender, device);
        vm.stopBroadcast();

        return auth;
    }
}
