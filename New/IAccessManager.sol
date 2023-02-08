// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./IAccessControlEnumerable.sol";

/// @title Interface for the AccessManager Smart Contract
/// @author Github: Labrys-Group
/// @notice Utilised to house all authorised accounts within the IMPT contract eco-system
interface IAccessManager is IAccessControlEnumerable {
  struct ConstructorParams {
    address superUser;
  }

  function bulkGrantRoles(
    bytes32[] calldata _roles,
    address[] calldata _addresses
  ) external;

  function transferDEXRoleAdmin() external;
}
