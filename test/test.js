const { expect } = require("chai");
const Web3 = require('web3');
const web3 = new Web3(hre.network.provider);
const BigNumber = require("bignumber.js")
BigNumber.config({ EXPONENTIAL_AT: 60 });

describe("Bridge", () => {

  let owner
  let validator
  let user0
  let token
  let token1
  let bridge

  const signRedeem = async (signer, params) => {
    const message = web3.utils.soliditySha3(
      { t: 'address', v: params.recipient },
      { t: 'string', v: params.symbol },
      { t: 'uint256', v: params.amount },
      { t: 'uint256', v: params.chainFrom },
      { t: 'uint256', v: params.chainTo },
      { t: 'uint256', v: params.txId },
      { t: 'address', v: bridge.address },
    );
    const signature = await web3.eth.sign(message, signer.address);
    return ethers.utils.splitSignature(signature);
  };

  before(async () => {
    [owner, validator, user0] = await ethers.getSigners();
  });

  it("deploy AcademyToken token", async () => {
    const Token = await ethers.getContractFactory("AcademyToken");
    token = await Token.deploy("Academy Token", "ACDM");
    token1 = await Token.deploy("Academy Token 2", "ACDM2");
    await token.mint(owner.address, new BigNumber('10000000').shiftedBy(18).toString());
    const balance = await token.balanceOf(owner.address);
    const symbol = await token.symbol();
    const humanBalance = new BigNumber(balance.toString()).shiftedBy(-18).toString();
    expect(symbol).to.equal('ACDM');
    expect(humanBalance).to.equal('10000000');
  });

  it("burn AcademyToken token", async () => {
    await token.burn(owner.address, '123');
    const balance = await token.balanceOf(owner.address);
    expect(balance).to.equal(new BigNumber('10000000').shiftedBy(18).minus('123').toString());
  });

  it("deploy Bridge and add token", async () => {
    const Bridge = await ethers.getContractFactory("Bridge");
    bridge = await Bridge.deploy('1');
    const VALIDATOR_ROLE = await bridge.VALIDATOR_ROLE();
    await bridge.grantRole(VALIDATOR_ROLE, validator.address);
    const MINTER_ROLE = await token.MINTER_ROLE();
    const BURNER_ROLE = await token.BURNER_ROLE();
    await token.grantRole(MINTER_ROLE, bridge.address);
    await token.grantRole(BURNER_ROLE, bridge.address);
    await token1.grantRole(MINTER_ROLE, bridge.address);
    await token1.grantRole(BURNER_ROLE, bridge.address);
    await bridge.addToken('ACDM', token.address);
    await bridge.addToken('ACDM2', token1.address);
    const tokenInfo = await bridge.tokenBySymbol('ACDM');
    expect(token.address).to.equal(tokenInfo.tokenAddress);
  });

  it("re-adding an existing symbol reverts", async () => {
    await expect(
      bridge.addToken('ACDM', token.address)
    ).to.be.revertedWith("Bridge: Token with given symbol already exists");
  });

  it("addToken from non-admin reverts", async () => {
    await expect(
      bridge.connect(user0).addToken('NEW', token.address)
    ).to.be.revertedWith("Bridge: You should have a admin role");
  });

  it("fetch chain", async () => {
    const chain = await bridge.currentChainId();
    expect('1').to.equal(chain.toString());
  });

  it("addChain", async () => {
    await bridge.updateChainById('2', true);
    const isChainActive = await bridge.isChainActiveById('2');
    expect(true).to.equal(isChainActive);
  });

  it("updateChainById from non-admin reverts", async () => {
    await expect(
      bridge.connect(user0).updateChainById('3', true)
    ).to.be.revertedWith("Bridge: You should have a admin role");
  });

  it("swap", async () => {
    await token.approve(bridge.address, '1000000');
    const amount = '1000';
    const balanceBefore = await token.balanceOf(owner.address);
    const expectedBalance = new BigNumber(balanceBefore.toString()).minus(amount).toString();
    await expect(
      bridge.swap(owner.address, 'ACDM', amount, '1', '2', '0')
    ).to.emit(bridge, 'SwapInitialized');
    const balanceAfter = await token.balanceOf(owner.address);
    expect(expectedBalance).to.equal(balanceAfter.toString());
  });

  it("swap replay reverts", async () => {
    await expect(
      bridge.swap(owner.address, 'ACDM', '1000', '1', '2', '0')
    ).to.be.revertedWith("Bridge: Swap with given params already exists");
  });

  it("fetch token list", async () => {
    const tokenList = await bridge.getTokenList();
    expect('ACDM2').to.equal(tokenList[1].symbol);
  });

  it("deactivate token", async () => {
    await expect(
      bridge.deactivateTokenBySymbol('ACDM2')
    ).to.emit(bridge, 'TokenStateChanged');
    const tokenList = await bridge.getTokenList();
    const INACTIVE = '2';
    expect(INACTIVE).to.equal(tokenList[1].state.toString());
  });

  it("deactivate from non-admin reverts", async () => {
    await expect(
      bridge.connect(user0).deactivateTokenBySymbol('ACDM')
    ).to.be.revertedWith("Bridge: You should have a admin role");
  });

  it("swap of inactive token reverts", async () => {
    await expect(
      bridge.swap(owner.address, 'ACDM2', '1000', '1', '2', '1')
    ).to.be.revertedWith("Bridge: Token is inactive");
  });

  it("activate from non-admin reverts", async () => {
    await expect(
      bridge.connect(user0).activateTokenBySymbol('ACDM2')
    ).to.be.revertedWith("Bridge: You should have a admin role");
  });

  it("activate token", async () => {
    await expect(
      bridge.activateTokenBySymbol('ACDM2')
    ).to.emit(bridge, 'TokenStateChanged');
  });

  it("redeem", async () => {
    const params = {
      recipient: user0.address,
      symbol: 'ACDM',
      amount: '666000666',
      chainFrom: '2',
      chainTo: '1',
      txId: '123'
    };
    const { v, r, s } = await signRedeem(validator, params);
    await expect(
      bridge.redeem(params.recipient, params.symbol, params.amount, params.chainFrom, params.chainTo, params.txId, v, r, s)
    ).to.emit(bridge, 'SwapRedeemed');
    const balance = await token.balanceOf(user0.address);
    expect('666000666').to.equal(balance.toString());
  });

  it("redeem replay reverts", async () => {
    const params = {
      recipient: user0.address,
      symbol: 'ACDM',
      amount: '666000666',
      chainFrom: '2',
      chainTo: '1',
      txId: '123'
    };
    const { v, r, s } = await signRedeem(validator, params);
    await expect(
      bridge.redeem(params.recipient, params.symbol, params.amount, params.chainFrom, params.chainTo, params.txId, v, r, s)
    ).to.be.revertedWith("Bridge: Redeem with given params already exists");
  });

  it("redeem with wrong chainTo reverts", async () => {
    const params = {
      recipient: user0.address,
      symbol: 'ACDM',
      amount: '1000',
      chainFrom: '1',
      chainTo: '2',
      txId: '777'
    };
    const { v, r, s } = await signRedeem(validator, params);
    await expect(
      bridge.redeem(params.recipient, params.symbol, params.amount, params.chainFrom, params.chainTo, params.txId, v, r, s)
    ).to.be.revertedWith("Bridge: Invalid chainTo is not current bridge chain");
  });

  it("redeem signed by non-validator reverts", async () => {
    const params = {
      recipient: user0.address,
      symbol: 'ACDM',
      amount: '1000',
      chainFrom: '2',
      chainTo: '1',
      txId: '778'
    };
    const { v, r, s } = await signRedeem(owner, params);
    await expect(
      bridge.redeem(params.recipient, params.symbol, params.amount, params.chainFrom, params.chainTo, params.txId, v, r, s)
    ).to.be.revertedWith("Bridge: Validator address is not correct");
  });

  it("redeem with malformed signature reverts", async () => {
    await expect(
      bridge.redeem(user0.address, 'ACDM', '1000', '2', '1', '779', 27, ethers.constants.HashZero, ethers.constants.HashZero)
    ).to.be.revertedWith("Bridge: Invalid signature");
  });
});
