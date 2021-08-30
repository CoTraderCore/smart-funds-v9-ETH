// SPDX-License-Identifier: MIT
// WARNING: THIS STRATEGY BIND WITH ETH

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

    uint public immutable interval;
    uint public lastTimeStamp;

    enum TradeType { Skip, Buy, Sell }


    constructor(
        uint updateInterval,
        address _router,
        address _poolAddress,
        address[] memory _path,
        address _fund,
        address _UNI_TOKEN
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

      previousPrice = getUNIPriceInETH();
    }

    // Helper for check 1 UNI price in ETH
    function getUNIPriceInETH()
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
        if(actionType == uint256(TradeType.Buy)){
          tradeFromETH(ethAmountToSell());
        }
        else if(actionType == uint256(TradeType.Sell)){
          tradeFromUNI(uniAmountToSell());
        }
        else{
          return; // no need action
        }

        // update data
        previousPrice = getUNIPriceInETH();
    }

    // compute if need trade
    // 0 - Skip, 1 - Buy, 2 - Sell
    function computeTradeAction() public view returns(uint){
       uint256 currentPrice = getUNIPriceInETH();

       // Buy if current price >= trigger % to buy
       if(currentPrice > previousPrice){
          uint256 currentDifference = currentPrice.sub(previousPrice);
          uint256 triggerPercent = previousPrice.div(100).mul(triggerPercentToBuy);

          uint256 res = currentDifference >= triggerPercent
          ? 1 // BUY
          : 0;

          return res;
       }

       // Sell if current price =< trigger % to sell
       else if(currentPrice < previousPrice){
          uint256 currentDifference = previousPrice.sub(currentPrice);
          uint256 triggerPercent = previousPrice.div(100).mul(triggerPercentToSell);

          uint256 res = currentDifference >= triggerPercent
          ? 2 // SELL
          : 0;

          return res;
       }
       else{
         return 0; // SKIP
       }
    }

    // Calculate how much % of ETH send from fund balance for buy UNI
    function ethAmountToSell() internal view returns(uint256){
      uint256 totatlETH = address(fund).balance;
      return totatlETH.div(100).mul(splitPercentToBuy);
    }

    // Calculate how much % of UNI send from fund balance for buy ETH
    function uniAmountToSell() internal view returns(uint256){
      uint256 totalUNI = IERC20(UNI_TOKEN).balanceOf();
      return totalUNI.div(100).mul(splitPercentToSell);
    }

    // Helper for trade from ETH
    function tradeFromETH(uint256 ethAmount) internal {
      bytes32[] memory proof;
      uint256[] memory positions;

      fund.trade(
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
        ethAmount,
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
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
        4,
        proof,
        positions,
        "0x",
        1
      );
    }
}
