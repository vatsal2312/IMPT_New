// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./libraries/LibIMPT.sol";
import "../interfaces/IAccessManager.sol";

contract AccessManager is IAccessManager, AccessControlEnumerable {
  constructor(ConstructorParams memory _params) {
    LibIMPT._checkZeroAddress(_params.superUser);
    _grantRole(DEFAULT_ADMIN_ROLE, _params.superUser);
  }

  /// @notice slither warning: "uninitialized-local" -- values changed in for loop
  /// @notice vulnerabilities of for loop mitigated with access control-- expecting max 10 interations
  function bulkGrantRoles(
    bytes32[] calldata _roles,
    address[] calldata _addresses
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_roles.length != _addresses.length) {
      revert ArrayLengthMismatch();
    }
    for (uint256 i; i < _roles.length; i += 1) {
      _grantRole(_roles[i], _addresses[i]);
    }
  }

  function transferDEXRoleAdmin()
    external
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    _setRoleAdmin(LibIMPT.IMPT_APPROVED_DEX, LibIMPT.IMPT_SALES_MANAGER);
  }
}