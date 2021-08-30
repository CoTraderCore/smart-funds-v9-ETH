// SPDX-License-Identifier: MIT
// NOTE: This strategy will not works for enabled merkletree verification funds
pragma solidity ^0.6.12;

import "./chainlink/AggregatorV3Interface.sol";
import "./chainlink/KeeperCompatibleInterface.sol";
import "../zeppelin-solidity/contracts/math/SafeMath.sol";

interface IRouter {
  function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IFund {
  function trade(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    uint256 _minReturn
  ) external;

  function getFundTokenHolding(address _token) external view returns (uint256);
  function coreFundAsset() external view returns(address);
}

interface IERC20 {
  function balanceOf() external view returns(uint256);
}

contract UNIBuyLowSellHigh is KeeperCompatibleInterface {
    using SafeMath for uint256;

    uint256 public previousPrice;
    address public poolAddress;
    uint256 public splitPercentToSell = 10;
    uint256 public splitPercentToBuy = 10;
    uint256 public triggerPercentToSell = 10;
    uint256 public triggerPercentToBuy = 10;

    IRouter public router;
    address[] public path;
    IFund public fund;
    address public UNI_TOKEN;
    address public UNDERLYING_ADDRESS;

    uint public immutable interval;
    uint public lastTimeStamp;

    enum TradeType { Skip, Buy, Sell }


    constructor(
        uint updateInterval, // seconds
        address _router, // Uniswap v2 router
        address _poolAddress, // Uniswap v2 pool (pair)
        address[] memory _path, // path [UNI, UNDERLYING]
        address _fund, // SmartFund address
        address _UNI_TOKEN // Uniswap token
      )
      public
    {
      interval = updateInterval;
      lastTimeStamp = block.timestamp;

      router = IRouter(_router);
      poolAddress = _poolAddress;
      path = _path;
      fund = IFund(_fund);
      UNI_TOKEN = _UNI_TOKEN;
      UNDERLYING_ADDRESS = fund.coreFundAsset();

      previousPrice = getUNIPriceInUNDERLYING();
    }

    // Helper for check price for 1 UNI in UNDERLYING
    function getUNIPriceInUNDERLYING()
      public
      view
      returns (uint256)
    {
      uint256[] memory res = router.getAmountsOut(1000000000000000000, path);
      return res[1];
    }

    // Check if need unkeep
    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;

        if(computeTradeAction() != 0)
          upkeepNeeded = true;
    }

    // Check if need perform unkeep
    function performUpkeep(bytes calldata) external override {
        lastTimeStamp = block.timestamp;

        // perform action
        uint256 actionType = computeTradeAction();

        // BUY action
        if(actionType == uint256(TradeType.Buy)){
          tradeFromUNDERLYING(underlyingAmountToSell());
        }
        // SELL action
        else if(actionType == uint256(TradeType.Sell)){
          tradeFromUNI(uniAmountToSell());
        }
        // NO need action
        else{
          return;
        }

        // update data after buy or sell action 
        previousPrice = getUNIPriceInUNDERLYING();
    }

    // compute if need trade
    // 0 - Skip, 1 - Buy, 2 - Sell
    function computeTradeAction() public view returns(uint){
       uint256 currentPrice = getUNIPriceInUNDERLYING();

       // Buy if current price >= trigger % to buy
       if(currentPrice > previousPrice){
          uint256 res = computeTrigger(currentPrice, previousPrice, triggerPercentToBuy)
          ? 1 // BUY
          : 0;

          return res;
       }

       // Sell if current price =< trigger % to sell
       else if(currentPrice < previousPrice){
         uint256 res = computeTrigger(previousPrice, currentPrice, triggerPercentToSell)
         ? 2 // SELL
         : 0;

         return res;
       }
       else{
         return 0; // SKIP
       }
    }

    // return true if difference >= trigger percent
    function computeTrigger(uint256 priceA, uint256 priceB, uint256 triggerPercent)
      public
      view
      returns(bool)
    {
      uint256 currentDifference = priceA.sub(priceB);
      uint256 triggerPercent = previousPrice.div(100).mul(triggerPercent);
      return currentDifference >= triggerPercent;
    }

    // Calculate how much % of UNDERLYING send from fund balance for buy UNI
    function underlyingAmountToSell() internal view returns(uint256){
      uint256 totatlETH = fund.getFundTokenHolding(UNDERLYING_ADDRESS);
      return totatlETH.div(100).mul(splitPercentToBuy);
    }

    // Calculate how much % of UNI send from fund balance for buy UNDERLYING
    function uniAmountToSell() internal view returns(uint256){
      uint256 totalUNI = IERC20(UNI_TOKEN).balanceOf();
      return totalUNI.div(100).mul(splitPercentToSell);
    }

    // Helper for trade from ETH
    function tradeFromUNDERLYING(uint256 underlyingAmount) internal {
      bytes32[] memory proof;
      uint256[] memory positions;

      fund.trade(
        UNDERLYING_ADDRESS,
        underlyingAmount,
        UNI_TOKEN,
        4,
        proof,
        positions,
        "0x",
        1
      );
    }

    // Helper for trade from UNI
    function tradeFromUNI(uint256 uniAmount) internal {
      bytes32[] memory proof;
      uint256[] memory positions;

      fund.trade(
        UNI_TOKEN,
        uniAmount,
        UNDERLYING_ADDRESS,
        4,
        proof,
        positions,
        "0x",
        1
      );
    }
}
