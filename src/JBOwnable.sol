// SPDX-License-Identifier: MIT
// Juicebox variation on OpenZeppelin Ownable

pragma solidity ^0.8.0;

import { JBOwner } from "./struct/JBOwner.sol";

import { IJBOperatorStore } from "@jbx-protocol/juice-contracts-v3/contracts/abstract/JBOperatable.sol";
import { IJBProjects } from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBProjects.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions and can grant other users permission to those functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner or an approved address.
 *
 * Supports meta-transactions.
 */
abstract contract JBOwnable is Context {
    //*********************************************************************//
    // --------------------------- custom errors --------------------------//
    //*********************************************************************//
    error UNAUTHORIZED();

    //*********************************************************************//
    // --------------------------- custom events --------------------------//
    //*********************************************************************//
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PermissionIndexChanged(uint8 newIndex);

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /** 
        @notice 
        A contract storing operator assignments.
    */
    IJBOperatorStore public immutable operatorStore;

    /**
        @notice
        The IJBProjects to use to get the owner of a project
     */
    IJBProjects public immutable projects;

    //*********************************************************************//
    // -------------------- private stored properties -------------------- //
    //*********************************************************************//

    /**
       @notice
       the JBOwner information
     */
    JBOwner private jbOwner;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /**
      @param _projects the JBProjects to use to get the owner of the project
      @param _operatorStore the operatorStore to use for the permissions
     */
    constructor(
        IJBProjects _projects,
        IJBOperatorStore _operatorStore
    ) {
        operatorStore = _operatorStore;
        projects = _projects;

        _transferOwnership(msg.sender, 0);
    }

    /**
     @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        JBOwner memory _ownerData = jbOwner;

        address _owner = _ownerData.projectId == 0 ?
         _ownerData.owner : projects.ownerOf(_ownerData.projectId);
        
        _requirePermission(_owner, _ownerData.projectId, _ownerData.permissionIndex);
        _;
    }

    /**
     @notice Returns the address of the current project owner.
    */
    function owner() public view virtual returns (address) {
        JBOwner memory _ownerData = jbOwner;

        if(_ownerData.projectId == 0)
            return _ownerData.owner;

        return projects.ownerOf(_ownerData.projectId);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0), 0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner, 0);
    }

    /**
     * @dev ProjectID is limited to a uint88, this should never give any issues
     */
    function transferOwnershipToProject(uint256 _projectId) public virtual onlyOwner {
        require(_projectId != 0);
        require(_projectId <= type(uint88).max);
        _transferOwnership(address(0), uint88(_projectId));
    }

    /**
     * @notice Sets the permission index that allows other callers to perform operations on behave of the project owner
     * @param _permissionIndex the permissionIndex to use for 'onlyOwner' calls
     */
    function setPermissionIndex(uint8 _permissionIndex) public virtual onlyOwner {
        _setPermissionIndex(_permissionIndex);
    }

    //*********************************************************************//
    // -------------------------- internal methods ----------------------- //
    //*********************************************************************//

    /**
     * @dev Sets the permission index that allows other callers to perform operations on behave of the project owner
     * Internal function without access restriction.
     * @param _permissionIndex the permissionIndex to use for 'onlyOwner' calls
     */
    function _setPermissionIndex(uint8 _permissionIndex) internal virtual {
        jbOwner.permissionIndex = _permissionIndex;
        emit PermissionIndexChanged(_permissionIndex);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address _newOwner, uint88 _projectId) internal virtual {
        // Can't both set a new owner and set a projectId to have ownership
        require(_newOwner == address(0) || _projectId == 0);
        // Load the owner data from storage
        JBOwner memory _ownerData = jbOwner;
        // Get an address representation of the old owner
        address _oldOwner = _ownerData.projectId == 0 ?
         _ownerData.owner : projects.ownerOf(_projectId);
        // Update the storage to the new owner and reset the permissionIndex
        // this is to prevent clashing permissions for the new user/owner
        jbOwner = JBOwner({
            owner: _newOwner,
            projectId: _projectId,
            permissionIndex: 0
        });
        // Emit the ownership transferred event using an address representation of the new owner
        emit OwnershipTransferred(_oldOwner, _projectId == 0 ? _newOwner : projects.ownerOf(_projectId));
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /** 
    @notice
    Require the message sender is either the account or has the specified permission.

    @param _account The account to allow.
    @param _domain The domain namespace within which the permission index will be checked.
    @param _permissionIndex The permission index that an operator must have within the specified domain to be allowed.
  */
    function _requirePermission(
        address _account,
        uint256 _domain,
        uint256 _permissionIndex
    ) internal view virtual {
        address _sender = _msgSender();
        if (
            _sender != _account &&
            !operatorStore.hasPermission(
                _sender,
                _account,
                _domain,
                _permissionIndex
            ) &&
            !operatorStore.hasPermission(_sender, _account, 0, _permissionIndex)
        ) revert UNAUTHORIZED();
    }

    /** 
    @notice
    Require the message sender is either the account, has the specified permission, or the override condition is true.

    @param _account The account to allow.
    @param _domain The domain namespace within which the permission index will be checked.
    @param _domain The permission index that an operator must have within the specified domain to be allowed.
    @param _override The override condition to allow.
  */
    function _requirePermissionAllowingOverride(
        address _account,
        uint256 _domain,
        uint256 _permissionIndex,
        bool _override
    ) internal view virtual {
        // short-circuit if the override is true
        if (_override) return;
        // Perform regular check otherwise
        _requirePermission(_account, _domain, _permissionIndex);
    }
}