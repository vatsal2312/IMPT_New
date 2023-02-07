// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// THIS CONTRACT IS FOR TESTING PURPOSES - NOT READY FOR THE REAL WORLD
//Contract to force an outcome that would otherwise be unpredictable to achieve using actual 0x protocol
contract MockZeroX {
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
    tokenValues.buyToken.transfer(msg.sender, tokenValues.buyAmount);
    data = abi.encodePacked(tokenValues.buyAmount);
  }
}
