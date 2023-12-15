// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import { Test } from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

import {MockOwnable, JBOwnableOverrides} from "../mocks/MockOwnable.sol";
import {IJBPermissions} from "lib/juice-contracts-v4/src/interfaces/IJBPermissions.sol";
import {JBPermissions} from "lib/juice-contracts-v4/src/JBPermissions.sol";
import {JBPermissionsData} from "lib/juice-contracts-v4/src/structs/JBPermissionsData.sol";
import {IJBProjects} from "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";
import {JBProjects} from "lib/juice-contracts-v4/src/JBProjects.sol";

contract OwnableHandler is CommonBase, StdCheats, StdUtils {
    IJBProjects public immutable PROJECTS;
    IJBPermissions public immutable PERMISSIONS;
    MockOwnable public immutable ownable;

    address[] public actors;
    address internal currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor() {
        address _initialOwner = vm.addr(1);
        // Deploy the permissions
        PERMISSIONS = new JBPermissions();
        // Deploy the JBProjects
        PROJECTS = new JBProjects(PERMISSIONS);
        // Deploy the JBOwnable
        vm.prank(_initialOwner);
        ownable = new MockOwnable(PROJECTS, PERMISSIONS);

        actors.push(_initialOwner);
        actors.push(address(420));
    }

    function transferOwnershipToAddress(uint256 actorIndexSeed, address _newOwner) public useActor(actorIndexSeed) {
        ownable.transferOwnership(_newOwner);
    }
}
