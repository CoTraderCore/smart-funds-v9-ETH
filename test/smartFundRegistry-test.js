import { BN, fromWei } from 'web3-utils'

import ether from './helpers/ether'
import EVMRevert from './helpers/EVMRevert'
import { duration } from './helpers/duration'
import latestTime from './helpers/latestTime'
import advanceTimeAndBlock from './helpers/advanceTimeAndBlock'
const BigNumber = BN

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

// real
const PermittedAddresses = artifacts.require('./core/verification/PermittedAddresses.sol')

// Factories
const SmartFundETHFactory = artifacts.require('./core/funds/SmartFundETHFactory.sol')
const SmartFundERC20Factory = artifacts.require('./core/funds/SmartFundERC20Factory.sol')

// Registry
const SmartFundRegistry = artifacts.require('./core/SmartFundRegistry.sol')

// Fund abi (View portals address)
const FundABI = [
	{
		"inputs": [],
		"name": "coreFundAsset",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "defiPortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "exchangePortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "platformAddress",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "poolPortal",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	}
]


contract('SmartFundRegistry', function([userOne, userTwo, userThree]) {
  beforeEach(async function() {

    this.COT = '0x0000000000000000000000000000000000000000'
    this.ExchangePortal = '0x0000000000000000000000000000000000000001'
    this.DAI = '0x0000000000000000000000000000000000000004'

    this.permittedAddresses = await PermittedAddresses.new(
      this.ExchangePortal,
      this.DAI
    )

    this.ETH_TOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'

    this.smartFundETHFactory = await SmartFundETHFactory.new()
    this.SmartFundERC20Factory = await SmartFundERC20Factory.new()


    this.registry = await SmartFundRegistry.new(
      this.ExchangePortal,                          //   ExchangePortal.address,
      this.smartFundETHFactory.address,             //   SmartFundETHFactory.address,
      this.SmartFundERC20Factory.address,           //   SmartFundERC20Factory.address
      this.permittedAddresses.address,              //   PermittedAddresses
    )
  })

  describe('INIT registry', function() {
    it('Correct initial totalFunds', async function() {
      const totalFunds = await this.registry.totalSmartFunds()
      assert.equal(0, totalFunds)
    })

    it('Correct initial ExchangePortal', async function() {
      assert.equal(this.ExchangePortal, await this.registry.exchangePortalAddress())
    })
  })

  describe('Create full funds', function() {
    it('should be able create new ETH fund and address in fund correct', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, this.ETH_TOKEN_ADDRESS, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.ETH_TOKEN_ADDRESS, await fund.methods.coreFundAsset().call())
    })

    it('should be able create new USD fund and address in fund correct', async function() {
      await this.registry.createSmartFund("USD Fund", 20, this.DAI, true)

      const fund = new web3.eth.Contract(FundABI, await this.registry.smartFunds(0))
      assert.equal(this.ExchangePortal, await fund.methods.exchangePortal().call())
      assert.equal(this.DAI, await fund.methods.coreFundAsset().call())
    })
  })

  describe('Should increase totalFunds after create new fund', function() {
    it('should be able create new ETH fund and address in fund correct', async function() {
      await this.registry.createSmartFund("ETH Fund", 20, this.ETH_TOKEN_ADDRESS, true)
      assert.equal(1, await this.registry.totalSmartFunds())

      await this.registry.createSmartFund("ETH Fund 2", 20, this.ETH_TOKEN_ADDRESS, true)
      assert.equal(2, await this.registry.totalSmartFunds())

      await this.registry.createSmartFund("ETH Fund 3", 20, this.ETH_TOKEN_ADDRESS, true)
      assert.equal(3, await this.registry.totalSmartFunds())
    })

  })

  describe('Update addresses', function() {
    const testAddress = '0x0000000000000000000000000000000000000777'


    it('Owner should be able change exchange portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 1)
      await this.registry.setExchangePortalAddress(testAddress)
      assert.equal(testAddress, await this.registry.exchangePortalAddress())
    })

    it('Owner should be able change maximumSuccessFee', async function() {
      await this.registry.setMaximumSuccessFee(4000)
      assert.equal(4000, await this.registry.maximumSuccessFee())
    })

    it('Owner should be able change ETH Factory', async function() {
      await this.registry.setNewSmartFundETHFactory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundETHFactory())
    })

    it('Owner should be able change ERC20 Factory', async function() {
      await this.registry.setNewSmartFundERC20Factory(testAddress)
      assert.equal(testAddress, await this.registry.smartFundERC20Factory())
    })


    it('NOT Owner should NOT be able change exchange portal address', async function() {
      await this.permittedAddresses.addNewAddress(testAddress, 1)
      await this.registry.setExchangePortalAddress(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change maximumSuccessFee', async function() {
      await this.registry.setMaximumSuccessFee(4000, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ETH Factory', async function() {
      await this.registry.setNewSmartFundETHFactory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })

    it('NOT Owner should NOT be able change ERC20 Factory', async function() {
      await this.registry.setNewSmartFundERC20Factory(testAddress, { from:userTwo })
      .should.be.rejectedWith(EVMRevert)
    })
  })
})
