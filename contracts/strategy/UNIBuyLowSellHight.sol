// SPDX-License-Identifier: MIT
// NOTE: This strategy will not works for enabled merkletree verification funds
pragma solidity ^0.6.12;

import "./chainlink/AggregatorV3Interface.sol";
import "./chainlink/KeeperCompatibleInterface.sol";
import "../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../zeppelin-solidity/contracts/access/Ownable.sol";

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

contract UNIBuyLowSellHigh is KeeperCompatibleInterface, Ownable {
    using SafeMath for uint256;

    uint256 public previousUnderlyingPrice;
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

    enum TradeType { Skip, BuyUNI, SellUNI }


    constructor(
        address _router, // Uniswap v2 router
        address _poolAddress, // Uniswap v2 pool (pair)
        address[] memory _path, // path [UNI, UNDERLYING]
        address _fund, // SmartFund address
        address _UNI_TOKEN // Uniswap token
      )
      public
    {
      router = IRouter(_router);
      poolAddress = _poolAddress;
      path = _path;
      fund = IFund(_fund);
      UNI_TOKEN = _UNI_TOKEN;
      UNDERLYING_ADDRESS = fund.coreFundAsset();

      previousUnderlyingPrice = getUNIPriceInUNDERLYING();
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
    function checkUpkeep(bytes calldata)
      external
      override
      returns (bool upkeepNeeded, bytes memory)
    {
        if(computeTradeAction() != 0)
          upkeepNeeded = true;
    }

    // Check if need perform unkeep
    function performUpkeep(bytes calldata) external override {
        // perform action
        uint256 actionType = computeTradeAction();

        // BUY action
        if(actionType == uint256(TradeType.BuyUNI)){
          // Trade from underlying to uni
          trade(
            UNDERLYING_ADDRESS,
            UNI_TOKEN,
            underlyingAmountToSell()
           );
        }
        // SELL action
        else if(actionType == uint256(TradeType.SellUNI)){
          // Trade from uni to underlying
          trade(
            UNI_TOKEN,
            UNDERLYING_ADDRESS,
            uniAmountToSell()
           );
        }
        // NO need action
        else{
          return;
        }

        // update data after buy or sell action
        previousUnderlyingPrice = getUNIPriceInUNDERLYING();
    }

    // compute if need trade
    // 0 - Skip, 1 - Buy, 2 - Sell
    function computeTradeAction() public view returns(uint){
       uint256 currentUnderlyingPrice = getUNIPriceInUNDERLYING();

       // Buy if current price >= trigger % to buy
       // This means UNI go UP
       if(currentUnderlyingPrice > previousUnderlyingPrice){
          uint256 res = computeTrigger(
            currentUnderlyingPrice,
            previousUnderlyingPrice,
            triggerPercentToBuy
          )
          ? 2 // SELL UNI
          : 0;

          return res;
       }

       // Sell if current price =< trigger % to sell
       // This means UNI go DOWN
       else if(currentUnderlyingPrice < previousUnderlyingPrice){
         uint256 res = computeTrigger(
           previousUnderlyingPrice,
           currentUnderlyingPrice,
           triggerPercentToSell
         )
         ? 1 // BUY UNI
         : 0;

         return res;
       }
       else{
         return 0; // SKIP
       }
    }

    // return true if difference >= trigger percent
    function computeTrigger(
      uint256 priceA,
      uint256 priceB,
      uint256 triggerPercent
    )
      public
      view
      returns(bool)
    {
      uint256 currentDifference = priceA.sub(priceB);
      uint256 triggerPercent = previousUnderlyingPrice.div(100).mul(triggerPercent);
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

    // Helper for trade
    function trade(address _fromToken, address _toToken, uint256 _amount) internal {
      bytes32[] memory proof;
      uint256[] memory positions;

      fund.trade(
        _fromToken,
        _amount,
        _toToken,
        4,
        proof,
        positions,
        "0x",
        1
      );
    }

    // Only owner setters
    function setSplitPercentToSell(uint256 _splitPercentToSell) external onlyOwner{
      require(splitPercentToSell <= 100, "Wrong %");
      splitPercentToSell = _splitPercentToSell;
    }

    function setSplitPercentToBuy(uint256 _splitPercentToBuy) external onlyOwner{
      require(splitPercentToBuy <= 100, "Wrong %");
      splitPercentToBuy = _splitPercentToBuy;
    }

    function setTriggerPercentToSell(uint256 _triggerPercentToSell) external onlyOwner{
      require(triggerPercentToSell <= 100, "Wrong %");
      triggerPercentToSell = _triggerPercentToSell;
    }

    function setTriggerPercentToBuy(uint256 _triggerPercentToBuy) external onlyOwner{
      require(triggerPercentToBuy <= 100, "Wrong %");
      triggerPercentToBuy = _triggerPercentToBuy;
    }
}
