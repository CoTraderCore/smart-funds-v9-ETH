import { BN, fromWei, toWei } from 'web3-utils'
import { MerkleTree } from 'merkletreejs'
import keccak256 from 'keccak256'
import ether from './helpers/ether'
import EVMRevert from './helpers/EVMRevert'
import { duration } from './helpers/duration'
import latestTime from './helpers/latestTime'
import advanceTimeAndBlock from './helpers/advanceTimeAndBlock'

const BigNumber = BN
const buf2hex = x => '0x'+x.toString('hex')

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

// real contracts
const SmartFundETH = artifacts.require('./core/funds/SmartFundETH.sol')
const PermittedAddresses = artifacts.require('./core/verification/PermittedAddresses.sol')
const MerkleWhiteList = artifacts.require('./core/verification/MerkleTreeTokensVerification.sol')
const STRATEGY = artifacts.require('./core/strategy/UNIBuyLowSellHigh.sol')
const ExchangePortal = artifacts.require('./core/portals/ExchangePortalLight.sol')
const PricePortalUniswap = artifacts.require('./core/portals/PricePortalUniswap.sol')

const UniswapV2Factory = artifacts.require('./dex/UniswapV2Factory.sol')
const UniswapV2Router = artifacts.require('./dex/UniswapV2Router02.sol')
const UniswapV2Pair = artifacts.require('./dex/UniswapV2Pair.sol')
const WETH = artifacts.require('./dex/WETH9.sol')

// mock
const Token = artifacts.require('./tokens/Token')
const CoTraderDAOWalletMock = artifacts.require('./CoTraderDAOWalletMock')
const OneInch = artifacts.require('./OneInchMock')


// Tokens keys converted in bytes32
const TOKEN_KEY_CRYPTOCURRENCY = "0x43525950544f43555252454e4359000000000000000000000000000000000000"

// Contracts instance
let xxxERC,
    DAI,
    exchangePortal,
    pricePortal,
    smartFundETH,
    permittedAddresses,
    oneInch,
    merkleWhiteList,
    MerkleTREE,
    COT_DAO_WALLET,
    uniswapV2Factory,
    uniswapV2Router,
    pairAddress,
    pair,
    weth,
    token,
    strategy



contract('SmartFundETH', function([userOne, userTwo, userThree]) {

  async function deployContracts(successFee=1000){
    oneInch = await OneInch.new()
    token = await Token.new(
      "TOKEN",
      "TOKEN",
      18,
      "1000000000000000000000000"
    )

    // Deploy DAI Token
    DAI = await Token.new(
      "DAI Stable Coin",
      "DAI",
      18,
      "1000000000000000000000000"
    )

    COT_DAO_WALLET = await CoTraderDAOWalletMock.new()

    // deploy DEX
    uniswapV2Factory = await UniswapV2Factory.new(userOne)
    weth = await WETH.new()
    uniswapV2Router = await UniswapV2Router.new(uniswapV2Factory.address, weth.address)

    // add token liquidity
    await token.approve(uniswapV2Router.address, toWei(String(100)))

    await uniswapV2Router.addLiquidityETH(
      token.address,
      toWei(String(100)),
      1,
      1,
      userOne,
      "1111111111111111111111"
    , { from:userOne, value:toWei(String(100)) })

    pairAddress = await uniswapV2Factory.allPairs(0)
    pair = await UniswapV2Pair.at(pairAddress)

    // Create MerkleTREE instance
    const leaves = [
      token.address,
      weth.address,
      ETH_TOKEN_ADDRESS
    ].map(x => keccak256(x)).sort(Buffer.compare)

    MerkleTREE = new MerkleTree(leaves, keccak256)

    // Deploy merkle white list contract
    merkleWhiteList = await MerkleWhiteList.new(MerkleTREE.getRoot())

    // Deplot pricePortal
    pricePortal = await PricePortalUniswap.new(
      weth.address,
      uniswapV2Router.address,
      uniswapV2Factory.address,
      [weth.address, token.address]
    )

    // Deploy exchangePortal
    exchangePortal = await ExchangePortal.new(
      pricePortal.address,
      oneInch.address,
      merkleWhiteList.address,
      weth.address,
      uniswapV2Router.address
    )

    // Deploy permitted address
    permittedAddresses = await PermittedAddresses.new(
      exchangePortal.address,
      DAI.address
    )

    // Deploy ETH fund
    smartFundETH = await SmartFundETH.new(
      userOne,                                      // address _owner,
      'TEST ETH FUND',                              // string _name,
      successFee,                                   // uint256 _successFee,
      COT_DAO_WALLET.address,                               // address _platformAddress,
      exchangePortal.address,                       // address _exchangePortalAddress,
      permittedAddresses.address,
      false                                          // verification for trade tokens
    )

    // Deploy strattegy
    strategy = await STRATEGY.new(
      120, // 2 minutes interval
      uniswapV2Router.address,
      pairAddress,
      [weth.address, token.address],
      smartFundETH.address,
      token.address
    )

    // Deposit in fund
    await smartFundETH.deposit({ from:userOne, value:toWei(String(100))})

    // Set strategy as swapper
    await smartFundETH.updateSwapperStatus(strategy.address, true)
  }

  beforeEach(async function() {
    await deployContracts()
  })

  describe('BUY and SELL indicators ', function() {
    it('should indicate skipp when price not trigger', async function() {
       assert.equal(await strategy.computeTradeAction(), 0)
    })

    it('should indicate buy when price go DOWN', async function() {
      // DUMP PRICE
      await token.approve(uniswapV2Router.address, toWei(String(50)))
      await uniswapV2Router.swapExactTokensForTokens(
         toWei(String(50)),
         1,
         [token.address, weth.address],
         userOne,
         "1111111111111111111"
         , { from: userOne }
       )

       assert.equal(await strategy.computeTradeAction(), 1)

       // should be 0 UNI
       assert.equal(await token.balanceOf(smartFundETH.address), 0)
       // perform Unkeep
       strategy.performUpkeep("0x")
       // should buy UNI
       assert.isTrue(await token.balanceOf(smartFundETH.address) > 0)
    })

    it('should indicate sell when price go UP', async function() {
       // PUMP PRICE
       await uniswapV2Router.swapExactETHForTokens(
         1,
         [weth.address, token.address],
         userOne,
         "1111111111111111111"
         , { from: userOne, value: toWei(String(50))}
       )

       assert.equal(await strategy.computeTradeAction(), 2)
    })
  })
  //END
})