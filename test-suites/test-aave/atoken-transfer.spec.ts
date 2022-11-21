import {
  APPROVAL_AMOUNT_LENDING_POOL,
  MAX_UINT_AMOUNT,
  ZERO_ADDRESS,
} from '../../helpers/constants';
import { convertToCurrencyDecimals } from '../../helpers/contracts-helpers';
import { expect } from 'chai';
import { ethers } from 'ethers';
import { RateMode, ProtocolErrors } from '../../helpers/types';
import { makeSuite, TestEnv } from './helpers/make-suite';
import { CommonsConfig } from '../../markets/aave/commons';

const AAVE_REFERRAL = CommonsConfig.ProtocolGlobalParams.AaveReferral;

makeSuite('AToken: Transfer', (testEnv: TestEnv) => {
  const {
    INVALID_FROM_BALANCE_AFTER_TRANSFER,
    INVALID_TO_BALANCE_AFTER_TRANSFER,
    VL_TRANSFER_NOT_ALLOWED,
  } = ProtocolErrors;

  it('User 0 deposits 1000 DAI, transfers to user 1', async () => {
    const { users, pool, dai, aDai } = testEnv;

    await dai.connect(users[0].signer).mint(await convertToCurrencyDecimals(dai.address, '1000'));

    await dai.connect(users[0].signer).approve(pool.address, APPROVAL_AMOUNT_LENDING_POOL);

    //user 1 deposits 1000 DAI
    const amountDAItoDeposit = await convertToCurrencyDecimals(dai.address, '1000');

    // 用户0往池子里存入1000 dai，得到1000个adai
    await pool
      .connect(users[0].signer)
      .deposit(dai.address, amountDAItoDeposit, users[0].address, '0');

    // 用户0把1000个aDAI转账给用户1
    await aDai.connect(users[0].signer).transfer(users[1].address, amountDAItoDeposit);

    const name = await aDai.name();

    expect(name).to.be.equal('Aave interest bearing DAI');

    const fromBalance = await aDai.balanceOf(users[0].address);
    const toBalance = await aDai.balanceOf(users[1].address);

    expect(fromBalance.toString()).to.be.equal('0', INVALID_FROM_BALANCE_AFTER_TRANSFER);
    expect(toBalance.toString()).to.be.equal(
      amountDAItoDeposit.toString(),
      INVALID_TO_BALANCE_AFTER_TRANSFER
    );
  });

  it('用户 0 存入 1 WETH ， 用户 1 尝试 to 借 the WETH 用 the 接受到的 DAI as 抵押', async () => {
    const { users, pool, weth, helpersContract } = testEnv;
    const userAddress = await pool.signer.getAddress();

    await weth.connect(users[0].signer).mint(await convertToCurrencyDecimals(weth.address, '1'));

    await weth.connect(users[0].signer).approve(pool.address, APPROVAL_AMOUNT_LENDING_POOL);

    //用户0网池子里存入1 weth， 得到1 aWETH
    await pool
      .connect(users[0].signer)
      .deposit(weth.address, ethers.utils.parseEther('1.0'), userAddress, '0');

    //用户1 用自己的aDAI作为抵押 从WETH池子里借 0.1 个， 利率模式是稳定， AaveReferral不知道啥意思
    await pool
      .connect(users[1].signer)
      .borrow(
        weth.address,
        ethers.utils.parseEther('0.1'),
        RateMode.Stable,
        AAVE_REFERRAL,
        users[1].address
      );

    //获取用户储备数据
    const userReserveData = await helpersContract.getUserReserveData(
      weth.address,
      users[1].address
    );

    //用户的储备数据应该有稳定利率贷款0.1个
    expect(userReserveData.currentStableDebt.toString()).to.be.eq(ethers.utils.parseEther('0.1'));
  });

  it('用户 1 尝试转让所有已经被作为 抵押物 的DAI 回给 to 用户 0 (revert expected)', async () => {
    const { users, pool, aDai, dai, weth } = testEnv;

    const aDAItoTransfer = await convertToCurrencyDecimals(dai.address, '1000');

    // aDAI是不允许转账的
    await expect(
      aDai.connect(users[1].signer).transfer(users[0].address, aDAItoTransfer),
      VL_TRANSFER_NOT_ALLOWED
    ).to.be.revertedWith(VL_TRANSFER_NOT_ALLOWED);
  });

  it('User 1 tries to transfer a small amount of DAI used as collateral back to user 0', async () => {
    const { users, pool, aDai, dai, weth } = testEnv;

    const aDAItoTransfer = await convertToCurrencyDecimals(dai.address, '100');

    await aDai.connect(users[1].signer).transfer(users[0].address, aDAItoTransfer);

    const user0Balance = await aDai.balanceOf(users[0].address);

    expect(user0Balance.toString()).to.be.eq(aDAItoTransfer.toString());
  });
});
