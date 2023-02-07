// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./libraries/LibIMPT.sol";
import "./libraries/SigRecovery.sol";

import "../interfaces/IMarketplace.sol";

// THIS CONTRACT IS FOR TESTING PURPOSES - NOT READY FOR THE REAL WORLD
contract Marketplace is IMarketplace, Pausable {
  using SafeERC20 for IERC20;

  ICarbonCreditNFT public override CarbonCreditNFT;
  IERC20 public override IMPTAddress;
  address public override IMPTTreasuryAddress;
  IAccessManager public override AccessManager;

  // Royalty percentage using PRB math: 100% = 1e18, 1% = 1e16
  uint256 public royaltyPercentage;

  // Sale Order Id's (from back-end) => used
  mapping(bytes24 => bool) public override usedSaleOrderIds;

  modifier onlyIMPTRole(bytes32 _role, IAccessManager _AccessManager) {
    LibIMPT._hasIMPTRole(_role, msg.sender, AccessManager);
    _;
  }

  constructor(ConstructorParams memory _params) {
    LibIMPT._checkZeroAddress(address(_params.CarbonCreditNFT));
    LibIMPT._checkZeroAddress(address(_params.IMPTAddress));
    LibIMPT._checkZeroAddress(_params.IMPTTreasuryAddress);
    LibIMPT._checkZeroAddress(address(_params.AccessManager));

    CarbonCreditNFT = _params.CarbonCreditNFT;
    IMPTAddress = _params.IMPTAddress;
    IMPTTreasuryAddress = _params.IMPTTreasuryAddress;
    AccessManager = _params.AccessManager;
  }

  function setRoyaltyPercentage(
    uint256 _royaltyPercentage
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    royaltyPercentage = _royaltyPercentage;

    emit RoyaltyPercentageChanged(_royaltyPercentage);
  }

  function setIMPTTreasury(
    address _implementation
  ) external override onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager) {
    LibIMPT._checkZeroAddress(_implementation);
    IMPTTreasuryAddress = _implementation;
    emit LibIMPT.IMPTTreasuryChanged(_implementation);
  }

  /// @dev This method verifies that the saleOrder and the provided _authorisationParams.expiry were signed by a backend wallet and the signature hasn't expired
  /// @param _authorisationParams The authorisation params that the backend generated
  /// @param _encodedSaleOrderRequest The sale order request abi encoded into a single bytes array
  function _verifyBackendSignature(
    AuthorisationParams calldata _authorisationParams,
    bytes calldata _authorisationSignature,
    bytes memory _encodedSaleOrderRequest
  ) internal view {
    // Concat the encoded sale order request with the backend expiry as this is how the signature was generated on the backend
    bytes memory encodedAuthorisationRequest = bytes.concat(
      _encodedSaleOrderRequest,
      abi.encode(_authorisationParams.expiry, _authorisationParams.to)
    );

    address recoveredAddress = SigRecovery.recoverAddressFromMessage(
      encodedAuthorisationRequest,
      _authorisationSignature
    );

    if (!AccessManager.hasRole(LibIMPT.IMPT_BACKEND_ROLE, recoveredAddress)) {
      revert LibIMPT.InvalidSignature();
    }

    if (_authorisationParams.expiry < block.timestamp) {
      revert LibIMPT.SignatureExpired();
    }

    if (_authorisationParams.to != msg.sender) {
      revert InvalidBuyer();
    }
  }

  /// @dev This method verifies the provided saleOrder
  /// @param _saleOrder The sellers sale order
  /// @param encodedSaleOrderRequest The sale order request abi encoded. Passing this as a parameter because it is also required as a parameter to another function
  /// @param _sellerSignature The sale order signed by the seller
  function _verifySaleOrder(
    SaleOrder calldata _saleOrder,
    bytes memory encodedSaleOrderRequest,
    bytes calldata _sellerSignature
  ) internal {
    address recoveredAddress = SigRecovery.recoverAddressFromMessage(
      encodedSaleOrderRequest,
      _sellerSignature
    );

    if (recoveredAddress != _saleOrder.seller) {
      revert LibIMPT.InvalidSignature();
    }

    if (_saleOrder.expiry < block.timestamp) {
      revert SaleOrderExpired();
    }

    // Ensure the sale order id hasn't been invalidated
    if (usedSaleOrderIds[_saleOrder.saleOrderId]) {
      revert SaleOrderIdUsed();
    }

    if (
      CarbonCreditNFT.balanceOf(_saleOrder.seller, _saleOrder.tokenId) <
      _saleOrder.amount
    ) {
      revert InsufficientSellerCarbonCreditBalance();
    }

    // Invalidate the sale order ID
    usedSaleOrderIds[_saleOrder.saleOrderId] = true;
  }

  function purchaseToken(
    AuthorisationParams calldata _authorisationParams,
    bytes calldata _authorisationSignature,
    SaleOrder calldata _saleOrder,
    bytes calldata _sellerOrderSignature
  ) external override whenNotPaused {
    // Encode the request here and re-use it in the verification methods to reduce computation
    bytes memory encodedSaleOrderRequest = abi.encode(
      _saleOrder.saleOrderId,
      _saleOrder.tokenId,
      _saleOrder.amount,
      _saleOrder.salePrice,
      _saleOrder.expiry,
      _saleOrder.seller
    );

    _verifySaleOrder(
      _saleOrder,
      encodedSaleOrderRequest,
      _sellerOrderSignature
    );
    _verifyBackendSignature(
      _authorisationParams,
      _authorisationSignature,
      encodedSaleOrderRequest
    );

    // Converts the salePrice value to the PRB math type to get the royalty amount and then converts it back to uint256 for usage
    uint256 royaltyAmount = unwrap(
      ud(_saleOrder.salePrice).mul(ud(royaltyPercentage))
    );

    uint256 saleReward = _saleOrder.salePrice - royaltyAmount;

    // Transfer the seller the reward amount
    IMPTAddress.safeTransferFrom(
      _authorisationParams.to,
      _saleOrder.seller,
      saleReward
    );

    if (royaltyAmount > 0) {
      // Transfer the treasury the royalty amount
      IMPTAddress.safeTransferFrom(
        _authorisationParams.to,
        IMPTTreasuryAddress,
        royaltyAmount
      );
    }

    CarbonCreditNFT.safeTransferFrom(
      _saleOrder.seller,
      _authorisationParams.to,
      _saleOrder.tokenId,
      _saleOrder.amount,
      ""
    );

    emit CarbonCreditSaleCompleted(
      _saleOrder.saleOrderId,
      _saleOrder.tokenId,
      _saleOrder.amount,
      _saleOrder.salePrice,
      _saleOrder.seller,
      _authorisationParams.to
    );
  }

  function pause()
    external
    override
    onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager)
  {
    _pause();
  }

  function unpause()
    external
    override
    onlyIMPTRole(LibIMPT.IMPT_ADMIN_ROLE, AccessManager)
  {
    _unpause();
  }
}
