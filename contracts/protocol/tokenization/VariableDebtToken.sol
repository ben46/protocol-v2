// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IVariableDebtToken} from '../../interfaces/IVariableDebtToken.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DebtTokenBase} from './base/DebtTokenBase.sol';
import {ILendingPool} from '../../interfaces/ILendingPool.sol';
import {IAaveIncentivesController} from '../../interfaces/IAaveIncentivesController.sol';

/**
 * @title VariableDebtToken 可变债务
 * @notice Implements a variable debt token to track the borrowing positions of users
 * at variable rate mode
 * @author Aave
 **/
contract VariableDebtToken is DebtTokenBase, IVariableDebtToken {
  //variable borrow rate index = (1 + Varialbe rate  ) * variable index

  //(1 + x) ^ y = 1 + xy +...
  //泰勒展开
  using WadRayMath for uint256;

  uint256 public constant DEBT_TOKEN_REVISION = 0x1;

  ILendingPool internal _pool;
  address internal _underlyingAsset;
  IAaveIncentivesController internal _incentivesController;

  /**
   * @dev Initializes the debt token.
   * @param pool The address of the lending pool where this aToken will be used
   * @param underlyingAsset The address of the underlying asset of this aToken (E.g. WETH for aWETH)
   * @param incentivesController The smart contract managing potential incentives distribution
   * @param debtTokenDecimals The decimals of the debtToken, same as the underlying asset's
   * @param debtTokenName The name of the token
   * @param debtTokenSymbol The symbol of the token
   */
  function initialize(
    ILendingPool pool,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 debtTokenDecimals,
    string memory debtTokenName,
    string memory debtTokenSymbol,
    bytes calldata params
  ) public override initializer {
    _setName(debtTokenName);
    _setSymbol(debtTokenSymbol);
    _setDecimals(debtTokenDecimals);

    _pool = pool;
    _underlyingAsset = underlyingAsset;
    _incentivesController = incentivesController;

    emit Initialized(
      underlyingAsset,
      address(pool),
      address(incentivesController),
      debtTokenDecimals,
      debtTokenName,
      debtTokenSymbol,
      params
    );
  }

  function balanceOf(address user) public view virtual override returns (uint256) {
    uint256 scaledBalance = super.balanceOf(user);
    if (scaledBalance == 0) {
      return 0;
    }
    //这里返回的也是复利,为啥债务是复利
    return scaledBalance.rayMul(_pool.getReserveNormalizedVariableDebt(_underlyingAsset));
  }

  function mint(
    address user,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool returns (bool) {
    // leding pool borrow的时候调用本函数(也只有lendingpool可以调用)

    if (user != onBehalfOf) {
      _decreaseBorrowAllowance(onBehalfOf, user, amount);
    }

    uint256 previousBalance = super.balanceOf(onBehalfOf);
    // 和atoken一样, 先给你按照汇率(index)换算一边
    // uint256 cumulatedVariableBorrowInterest =
    //         MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp);这里用了泰勒级数展开(展开到第三极)
    //variableBorrowIndex *= cumulatedVariableBorrowInterest
    //amountScaled = amount * variableBorrowIndex
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_MINT_AMOUNT);

    _mint(onBehalfOf, amountScaled);

    emit Transfer(address(0), onBehalfOf, amount);
    emit Mint(user, onBehalfOf, amount, index);

    return previousBalance == 0;
  }

  function burn(
    address user,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.CT_INVALID_BURN_AMOUNT);

    _burn(user, amountScaled);

    emit Transfer(user, address(0), amount);
    emit Burn(user, amount, index);
  }

  function scaledBalanceOf(address user) public view virtual override returns (uint256) {
    return super.balanceOf(user);
  }

  function totalSupply() public view virtual override returns (uint256) {
    return super.totalSupply().rayMul(_pool.getReserveNormalizedVariableDebt(_underlyingAsset));
  }

  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (super.balanceOf(user), super.totalSupply());
  }

  function UNDERLYING_ASSET_ADDRESS() public view returns (address) {
    return _underlyingAsset;
  }

  function getIncentivesController() external view override returns (IAaveIncentivesController) {
    return _getIncentivesController();
  }

  function POOL() public view returns (ILendingPool) {
    return _pool;
  }

  function _getIncentivesController() internal view override returns (IAaveIncentivesController) {
    return _incentivesController;
  }

  function _getUnderlyingAssetAddress() internal view override returns (address) {
    return _underlyingAsset;
  }

  function _getLendingPool() internal view override returns (ILendingPool) {
    return _pool;
  }

  function getRevision() internal pure virtual override returns (uint256) {
    //token 版本号
    return DEBT_TOKEN_REVISION;
  }
}
