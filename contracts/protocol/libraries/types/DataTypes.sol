// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {

    //stores the reserve configuration
    ReserveConfigurationMap configuration;

    //cummulated liquidity index. Expressed in ray
    //累计流动性指数(类似compound的汇率)
    //存款之后会有存款利率,存款利率用这个累计流动性指数的方式来记录
    uint128 liquidityIndex;// LI = (LR * deltaT + 1) * LI   note:LI0 = 1 ray    LR = liquidity rate

    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;

    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;//当前资产的流动性率(存款利率) = 资金利用率 * 贷款利率

    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;

    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}
