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



contract('Strategy UNI/WETH', function([userOne, userTwo, userThree]) {

  async function deployContracts(tokenLD=100, ethLD=100){
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
    await token.approve(uniswapV2Router.address, toWei(String(tokenLD)))

    console.log("tokenLD", tokenLD, "ethLD", ethLD)

    await uniswapV2Router.addLiquidityETH(
      token.address,
      toWei(String(tokenLD)),
      1,
      1,
      userOne,
      "1111111111111111111111"
    , { from:userOne, value:toWei(String(ethLD)) })

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
      1000,                                         // uint256 _successFee,
      COT_DAO_WALLET.address,                       // address _platformAddress,
      exchangePortal.address,                       // address _exchangePortalAddress,
      permittedAddresses.address,
      false                                         // verification for trade tokens
    )

    // Deploy strattegy
    strategy = await STRATEGY.new(
      uniswapV2Router.address,
      pairAddress,
      smartFundETH.address,
      token.address,
      weth.address
    )

    // Deposit in fund
    await smartFundETH.deposit({ from:userOne, value:toWei(String(100))})

    // Set strategy as swapper
    await smartFundETH.updateSwapperStatus(strategy.address, true)
  }


  describe('BUY and SELL indicators should works correct for pool 1 to 1', async function() {
    const uniLD = 100
    const ethLD = 100
    const tokenToSell = 50
    const ethToSell = 50

    it('should indicate skipp when price not trigger', async function() {
       await deployContracts(uniLD, ethLD)
       assert.equal(await strategy.computeTradeAction(), 0)
    })


    it('should indicate buy when ETH price go DOWN to UNI ', async function() {
      await deployContracts(uniLD, ethLD)
      console.log(
        "rate rate 100 to 100", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1)
      )
      // DUMP PRICE
      await token.approve(uniswapV2Router.address, toWei(String(tokenToSell)))

      await uniswapV2Router.swapExactTokensForTokens(
         toWei(String(tokenToSell)),
         1,
         [token.address, weth.address],
         userOne,
         "1111111111111111111"
         , { from: userOne }
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1),
         "LD amount", Number(fromWei(await strategy.getLDAmount())).toFixed(1)
       )

       assert.equal(await strategy.computeTradeAction(), 2) // Should sell UNI
    })


    it('should indicate sell when ETH price go UP to UNI', async function() {
       await deployContracts(uniLD, ethLD)
       // PUMP PRICE
       await uniswapV2Router.swapExactETHForTokens(
         1,
         [weth.address, token.address],
         userOne,
         "1111111111111111111"
         , { from: userOne, value: toWei(String(ethToSell))}
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1),
         "LD amount", Number(fromWei(await strategy.getLDAmount())).toFixed(1)
       )
       assert.equal(await strategy.computeTradeAction(), 1) // Should buy UNI
    })
  })

  describe('BUY and SELL indicators should works correct for pool 1000 to 1', async function() {
    const uniLD = 1000
    const ethLD = 1
    const tokenToSell = 500
    const ethToSell = 500

    it('should indicate skipp when price not trigger', async function() {
       await deployContracts(uniLD, ethLD)
       assert.equal(await strategy.computeTradeAction(), 0)
    })


    it('should indicate buy when ETH price go DOWN to UNI 1', async function() {

      await deployContracts(uniLD, ethLD)

      console.log(
        "LD / RATE prev ", Number(await strategy.previousLDRatePrice()),
        "LD / RATE current ", Number(await strategy.getLDRatePrice()),
        "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())),
        "LD amount", Number(fromWei(await strategy.getLDAmount()))
      )

      // DUMP PRICE
      await token.approve(uniswapV2Router.address, toWei(String(tokenToSell)))

      await uniswapV2Router.swapExactTokensForTokens(
         toWei(String(tokenToSell)),
         1,
         [token.address, weth.address],
         userOne,
         "1111111111111111111"
         , { from: userOne }
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())),
         "LD amount", Number(fromWei(await strategy.getLDAmount()))
       )

       assert.equal(await strategy.computeTradeAction(), 2) // Should sell UNI
    })


    it('should indicate sell when ETH price go UP to UNI', async function() {
       await deployContracts(1000, 1)
       // PUMP PRICE
       await uniswapV2Router.swapExactETHForTokens(
         1,
         [weth.address, token.address],
         userOne,
         "1111111111111111111"
         , { from: userOne, value: toWei(String(ethToSell))}
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1),
         "LD amount", Number(fromWei(await strategy.getLDAmount())).toFixed(1)
       )
       assert.equal(await strategy.computeTradeAction(), 1) // Should buy UNI
    })
  })


  describe('BUY and SELL indicators should works correct for pool 1 to 1000', async function() {
    const uniLD = 1
    const ethLD = 1000
    const tokenToSell = 500
    const ethToSell = 500

    it('should indicate skipp when price not trigger', async function() {
       await deployContracts(uniLD, ethLD)
       assert.equal(await strategy.computeTradeAction(), 0)
    })


    it('should indicate buy when ETH price go DOWN to UNI 2', async function() {
      await deployContracts(uniLD, ethLD)

      // DUMP PRICE
      await token.approve(uniswapV2Router.address, toWei(String(tokenToSell)))

      await uniswapV2Router.swapExactTokensForTokens(
         toWei(String(tokenToSell)),
         1,
         [token.address, weth.address],
         userOne,
         "1111111111111111111"
         , { from: userOne }
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1),
         "LD amount", Number(fromWei(await strategy.getLDAmount())).toFixed(1)
       )

       assert.equal(await strategy.computeTradeAction(), 2) // Should sell UNI
    })


    it('should indicate sell when ETH price go UP to UNI', async function() {
       await deployContracts(uniLD, ethLD)
       // PUMP PRICE
       await uniswapV2Router.swapExactETHForTokens(
         1,
         [weth.address, token.address],
         userOne,
         "1111111111111111111"
         , { from: userOne, value: toWei(String(ethToSell))}
       )

       console.log(
         "LD / RATE before", Number(await strategy.previousLDRatePrice()),
         "LD / RATE", Number(await strategy.getLDRatePrice()),
         "rate ", Number(fromWei(await strategy.getUNIPriceInUNDERLYING())).toFixed(1),
         "LD amount", Number(fromWei(await strategy.getLDAmount())).toFixed(1)
       )
       assert.equal(await strategy.computeTradeAction(), 1) // Should buy UNI
    })
  })
  //END
})
