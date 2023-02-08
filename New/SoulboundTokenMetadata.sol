// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Strings.sol";
import "./Base64.sol";

import "./ISoulboundToken.sol";

library SoulboundTokenMetadata {
  using Strings for uint256;

  function formatJsonField(
    string memory _fieldName,
    string memory _value,
    bool _addComma
  ) internal pure returns (bytes memory formattedJsonField) {
    formattedJsonField = abi.encodePacked(
      '"',
      _fieldName,
      '": ',
      '"',
      _value,
      '"'
    );

    if (_addComma) {
      formattedJsonField = bytes.concat(
        formattedJsonField,
        abi.encodePacked(",")
      );
    }
  }

  function formatTokenType(
    ISoulboundToken.TokenType memory _tokenType,
    uint256 _value,
    bool _addComma
  ) internal pure returns (bytes memory formattedTokenType) {
    formattedTokenType = abi.encodePacked(
      "{",
      formatJsonField("trait_type", _tokenType.displayName, true),
      formatJsonField("value", _value.toString(), false),
      "}"
    );

    if (_addComma) {
      formattedTokenType = bytes.concat(
        formattedTokenType,
        abi.encodePacked(",")
      );
    }
  }

  function formatTokenTypesInMetadata(
    ISoulboundToken.TokenType[] memory _tokenTypes,
    uint256[] memory _userBurnedCounts
  ) internal pure returns (bytes memory attributes) {
    attributes = abi.encodePacked('"attributes": [');

    for (uint256 i = 0; i < _tokenTypes.length; i++) {
      bytes memory formattedType = formatTokenType(
        _tokenTypes[i],
        _userBurnedCounts[i],
        i != _tokenTypes.length - 1
      );

      attributes = bytes.concat(attributes, formattedType);
    }

    attributes = bytes.concat(attributes, "]");
  }

  function buildTokenURI(
    ISoulboundToken.TokenType[] memory _tokenTypes,
    string memory _name,
    string memory _metadataURI,
    string memory _description,
    uint256 _tokenId,
    uint256[] memory _userBurnedCounts
  ) internal pure returns (string memory) {
    bytes memory dataURI = abi.encodePacked(
      "{",
      '"name": "',
      _name,
      " #",
      _tokenId.toString(),
      '",',
      SoulboundTokenMetadata.formatJsonField("image", _metadataURI, true),
      SoulboundTokenMetadata.formatJsonField("description", _description, true),
      SoulboundTokenMetadata.formatTokenTypesInMetadata(_tokenTypes, _userBurnedCounts),
      "}"
    );

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(dataURI)
        )
      );
  }
}
