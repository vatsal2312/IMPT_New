// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Contract to force an outcome that would otherwise be unpredictable to achieve using actual 0x protocol
contract MockZeroX {
  using SafeERC20 for ERC20;
  struct TokenValues {
    ERC20 sellToken;
    ERC20 buyToken;
    uint256 sellAmount;
    uint256 buyAmount;
  }

  TokenValues public tokenValues;

  constructor() {}

  function setValues(TokenValues calldata _tokenValues) public {
    tokenValues = _tokenValues;
  }

  //Using this for mocking purposes only
  function approve(address, uint256) public returns (bool) {
    return true;
  }

  fallback(bytes calldata) external returns (bytes memory data) {
    tokenValues.sellToken.transferFrom(
      msg.sender,
      address(this),
      tokenValues.sellAmount
    );
    tokenValues.buyToken.safeTransfer(msg.sender, tokenValues.buyAmount);
    data = abi.encodePacked(tokenValues.buyAmount);
  }
}
