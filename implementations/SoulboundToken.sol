// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./libraries/SoulboundTokenMetadata.sol";
import "./libraries/LibIMPT.sol";
import "../interfaces/ISoulboundToken.sol";

contract SoulboundToken is ISoulboundToken, Initializable, UUPSUpgradeable {
  //###################
  //#### Libraries ####
  using AddressUpgradeable for address;
  using StringsUpgradeable for uint256;
  using CountersUpgradeable for CountersUpgradeable.Counter;
  //###################
  //#### Variables ####
  string private _name;
  string private _symbol;
  string private _description;

  ISoulboundToken.TokenType[] public tokenTypes;
  ICarbonCreditNFT public override carbonCreditContract;
  IAccessManager public override AccessManager;

  //##################
  //#### Mappings ####
  // Map token ID to token index in tokenTypes array
  mapping(uint256 => uint256) public tokenIdToIndexMapping;

  // Mapping from token ID to owner address
  mapping(uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping(address => uint256) private _balances;

  // Mapping owner address to Token ID
  mapping(address => uint256) public ownerTokenID;

  //Mapping token ID to image URI
  mapping(uint256 => string) public tokenIdToImageUri;

  // Mapping owner to token ID to burn count
  mapping(address => mapping(uint256 => uint256))
    public
    override usersBurnedCounts;

  //######### DECLARE NEW VARIABLES FOR UPGRADEABLE HERE #############
  CountersUpgradeable.Counter private tokenCounter;

  modifier nftOnly() {
    if (msg.sender != address(carbonCreditContract)) {
      revert UnauthorizedCall();
    }
    _;
  }

  modifier onlyIMPTRole(bytes32 _role, IAccessManager _AccessManager) {
    LibIMPT._hasIMPTRole(_role, msg.sender, AccessManager);
    _;
  }

  //###################################################################
  //#### Constructor-- Replaced with initialize for upgradeability ####
  function initialize(
    ISoulboundToken.ConstructorParams calldata _params
  ) external initializer {
    LibIMPT._checkZeroAddress(address(_params._carbonCreditContract));
    LibIMPT._checkZeroAddress(address(_params.AccessManager));
    __UUPSUpgradeable_init();

    AccessManager = _params.AccessManager;

    _name = _params.name_;
    _symbol = _params.symbol_;
    _description = _params.description_;
    carbonCreditContract = _params._carbonCreditContract;

    // Increment token ID so IDs start at 1
    tokenCounter.increment();
  }

  //###########################
  //#### CUSTOM FUNCTIONS ####
  function setCarbonCreditContract(
    ICarbonCreditNFT _carbonCreditContract
  ) public override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(address(_carbonCreditContract));
    carbonCreditContract = _carbonCreditContract;
    emit CarbonNftContractUpdated(_carbonCreditContract);
  }

  function mint(
    address to,
    string calldata imageURI
  ) external override onlyIMPTRole(LibIMPT.IMPT_MINTER_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(to);
    uint256 currentTokenId = tokenCounter.current();

    if (balanceOf(to) != 0) {
      revert HasToken();
    }

    // Update state variables
    tokenIdToImageUri[currentTokenId] = imageURI;
    _owners[currentTokenId] = to;
    ownerTokenID[to] = currentTokenId;
    _balances[to] += 1;

    // Increment for next call
    tokenCounter.increment();

    emit Transfer(address(0), to, currentTokenId);
  }

  function getCurrentTokenId() public view returns (uint256) {
    return tokenCounter.current();
  }

  function incrementRetireCount(
    address user,
    uint256 tokenId,
    uint256 amount
  ) external override nftOnly {
    usersBurnedCounts[user][tokenId] += amount;

    emit RetireCountUpdated(user, tokenId, amount);
  }

  function tokenURI(
    uint256 _tokenId
  ) external view override returns (string memory) {
    address tokenOwner = ownerOf(_tokenId);
    ISoulboundToken.TokenType[] memory tokens = tokenTypes;
    uint256[] memory userBurnedArray = new uint256[](tokens.length);

    for (uint8 i = 0; i < tokens.length; i++) {
      uint256 userBurnedCount = usersBurnedCounts[tokenOwner][
        tokens[i].tokenId
      ];
      userBurnedArray[i] = userBurnedCount;
    }

    string memory encodedURI = SoulboundTokenMetadata.buildTokenURI(
      tokenTypes,
      _name,
      tokenIdToImageUri[_tokenId],
      _description,
      _tokenId,
      userBurnedArray
    );

    return encodedURI;
  }

  function getAllTokenTypes()
    external
    view
    override
    returns (ISoulboundToken.TokenType[] memory)
  {
    return tokenTypes;
  }

  function addTokenType(
    ISoulboundToken.TokenType calldata _tokenType
  ) public override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    ISoulboundToken.TokenType memory newTokenType = ISoulboundToken.TokenType(
      _tokenType.displayName,
      _tokenType.tokenId
    );
    tokenIdToIndexMapping[_tokenType.tokenId] = tokenTypes.length;
    tokenTypes.push(newTokenType);

    emit TokenTypeAdded(_tokenType);
  }

  function removeTokenType(
    uint256 _tokenId
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    if (tokenTypes.length <= 0) {
      revert NoTokenTypes();
    }

    uint256 _tokenIndex = tokenIdToIndexMapping[_tokenId];

    if (tokenTypes[_tokenIndex].tokenId != _tokenId) {
      revert TokenIdNotFound();
    }

    if (_tokenIndex == tokenTypes.length - 1) {
      tokenTypes.pop();
    } else {
      ISoulboundToken.TokenType memory lastTokenTypeElement = tokenTypes[
        tokenTypes.length - 1
      ];
      tokenTypes[_tokenIndex] = lastTokenTypeElement;
      tokenIdToIndexMapping[lastTokenTypeElement.tokenId] = _tokenIndex;
      tokenTypes.pop();
    }

    emit TokenTypeRemoved(_tokenId);
  }

  //############################
  //#### STANDARD FUNCTIONS ####
  /// @dev This function is to check that the upgrade functions in UUPSUpgradeable are being called by an address with the correct role
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {}

  function name() external view virtual override returns (string memory) {
    return _name;
  }

  function symbol() external view virtual override returns (string memory) {
    return _symbol;
  }

  function description()
    external
    view
    virtual
    override
    returns (string memory)
  {
    return _description;
  }

  function balanceOf(
    address owner
  ) public view virtual override returns (uint256) {
    LibIMPT._checkZeroAddress(owner);
    return _balances[owner];
  }

  function ownerOf(
    uint256 tokenId
  ) public view virtual override returns (address) {
    return _ownerOf(tokenId);
  }

  function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
    return _owners[tokenId];
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(IERC165) returns (bool) {
    return interfaceId == type(IERC165).interfaceId;
  }
}
