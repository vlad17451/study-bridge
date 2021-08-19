const { expect } = require("chai");
const Web3 = require('web3');
const web3 = new Web3(hre.network.provider);
const BigNumber = require("bignumber.js")
BigNumber.config({ EXPONENTIAL_AT: 60 });

const BN = BigNumber;

describe("tests", async () => {

  let token
  let token1
  let bridge


  beforeEach(async function () {
    [owner, validator, user0] = await ethers.getSigners();
  });

  it("deploy AcademyToken token", async () => {
    const Token = await ethers.getContractFactory("AcademyToken");
    token = await Token.deploy("Academy Token", "ACDM");
    token1 = await Token.deploy("Academy Token 2", "ACDM2");
    await token.mint(owner.address, new BigNumber('10000000').shiftedBy(18).toString());
    let balance = await token.balanceOf(owner.address);
    let symbol = await token.symbol();
    balance = new BigNumber(balance.toString()).shiftedBy(-18).toString()
    expect(symbol).to.equal('ACDM');
    expect(balance).to.equal('10000000');
  });

  it("burn AcademyToken token", async () => {
    await token.burn(owner.address, '123')
    let balance = await token.balanceOf(owner.address);
    expect(balance).to.equal(new BigNumber('10000000').shiftedBy(18).minus('123').toString());
  });

  it("deploy Bridge and add token token", async () => {
    const Bridge = await ethers.getContractFactory("Bridge");
    bridge = await Bridge.deploy('1');
    const VALIDATOR_ROLE = await bridge.VALIDATOR_ROLE()
    await bridge.grantRole(VALIDATOR_ROLE, validator.address)
    const MINTER_ROLE = await token.MINTER_ROLE()
    const BURNER_ROLE = await token.BURNER_ROLE()
    await token.grantRole(MINTER_ROLE, bridge.address)
    await token.grantRole(BURNER_ROLE, bridge.address)
    await bridge.addToken('ACDM', token.address);
    await bridge.addToken('ACDM2', token1.address);
    const tokenAddress = await bridge.tokenBySymbol('ACDM');
    expect(token.address).to.equal(tokenAddress.token);
  });

  it("fetch chain", async () => {
    const chain = await bridge.currentBridgeChain()
    expect('1').to.equal(chain.toString());
  });

  it("swap", async () => {
    await token.approve(bridge.address, '1000000');
    const amount = '1000'
    let balance1 = await token.balanceOf(owner.address);
    const expectedBalance = new BigNumber(balance1.toString()).minus(amount).toString()
    await bridge.swap(owner.address, 'ACDM', amount, '0', '1', '0')
    let balance2 = await token.balanceOf(owner.address);
    expect(expectedBalance).to.equal(balance2.toString());
  });

  it("fetch token list", async () => {
    const tokenList = await bridge.getTokenList()
    expect('ACDM2').to.equal(tokenList[1].symbol);
  });

  it("deactivate token", async () => {
    await bridge.deactivateTokenBySymbol('ACDM2')
    const tokenList = await bridge.getTokenList()
    expect('1').to.equal(tokenList[1].state.toString());
  });

  it("redeem", async () => {

    const recipient = user0.address
    const symbol = 'ACDM'
    const amount = '666000666'
    const chainFrom = '1'
    const chainTo = '2'
    const txId = '123'
    const message = web3.utils.soliditySha3(
      { t: 'address', v: recipient },
      { t: 'string', v: symbol },
      { t: 'uint256', v: amount },
      { t: 'uint256', v: chainFrom },
      { t: 'uint256', v: chainTo },
      { t: 'uint256', v: txId },
    );
    const signature = await web3.eth.sign(message, validator.address);
    const { v, r, s }  = ethers.utils.splitSignature(signature)
    // console.log('address0: ', validator.address)
    await bridge.redeem(recipient, symbol, amount, chainFrom, chainTo, txId, v, r, s)
    const balance = await token.balanceOf(user0.address);
    console.log(balance.toString())

  });
});
