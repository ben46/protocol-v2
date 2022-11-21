pragma solidity ^0.6.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../../interfaces/ILendingPoolAddressesProvider.sol';
import '../../interfaces/ILendingPool.sol';

contract Liquidator {
  address immutable lendingPoolAddressProvider;

  constructor(address _lendingPoolAddress) public {
    lendingPoolAddressProvider = _lendingPoolAddress;
  }

  function myLiquidationFunction(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount,
    bool _receiveaToken
  ) external {
    ILendingPoolAddressesProvider addressProvider =
      ILendingPoolAddressesProvider(lendingPoolAddressProvider);

    ILendingPool lendingPool = ILendingPool(addressProvider.getLendingPool());

    //  调用前保证LendingPool合约可以转入用于清算债务的资产
    require(IERC20(_reserve).approve(address(lendingPool), _purchaseAmount), 'Approval error');

    // Assumes this contract already has `_purchaseAmount` of `_reserve`.
    lendingPool.liquidationCall(_collateral, _reserve, _user, _purchaseAmount, _receiveaToken);
  }
}
