// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./chainlink/AggregatorV3Interface.sol";
import "./chainlink/KeeperCompatibleInterface.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";

interface IRouter {
  function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract UNIBuyLowSellHigh is KeeperCompatibleInterface {
    using SafeMath for uint256;

    uint public previousPrice;
    address public poolAddress;
    uint256 public splitPercentToSell;
    uint256 public splitPercentToBuy;
    uint256 public triggerPercentToSell;
    uint256 public triggerPercentToBuy;

    IRouter public router;
    address[] public path;

    uint public immutable interval;
    uint public lastTimeStamp;

    enum TradeType { Skip, Buy, Sell }


    constructor(
        uint updateInterval,
        address _router,
        address _poolAddress,
        address[] memory _path
      )
      public
    {
      interval = updateInterval;
      lastTimeStamp = block.timestamp;

      router = IRouter(_router);
      poolAddress = _poolAddress;
      path = _path;

      previousPrice = getUNIPriceInETH();
    }

    function getUNIPriceInETH()
      public
      view
      returns (uint256)
    {
      uint256[] memory res = router.getAmountsOut(1000000000000000000, path);
      return res[1];
    }

    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;

        if(computeTradeAction() !== 0)
          upkeepNeeded = true
    }

    function performUpkeep(bytes calldata) external override {
        lastTimeStamp = block.timestamp;
    }

    // compute if need trade
    // 0 - Skip, 1 - Buy, 2 - Sell
    function computeTradeAction() public view returns(uint){
       currentPrice = getUNIPriceInETH();

       if(currentPrice > previousPrice){
          uint256 currentDifference = currentPrice.sub(previousPrice);
          uint256 triggerPercent = previousPrice.div(100).mul(triggerPercentToBuy);

          triggerPercent > currentDifference
          ? return 1 // BUY
          : return 0
       }
       else if(currentPrice < previousPrice){
          uint256 currentDifference = previousPrice.sub(currentPrice);
          uint256 triggerPercent = previousPrice.div(100).mul(triggerPercentToSell);

          triggerPercent > currentDifference
          ? return 2 // SELL
          : return 0
       }
       else{
         return 0 // SKIP
       }
    }
}
