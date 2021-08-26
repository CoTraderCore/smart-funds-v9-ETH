import "../interfaces/IDecimals.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../uniswap/interfaces/IUniswapV2Router.sol";
import "../../zeppelin-solidity/contracts/access/Ownable.sol";

interface Router {
  function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}


contract PricePortalPancake is Ownable {
  address public WETH;
  address public pancakeRouter;
  address public coswapRouter;
  address public bCOT;
  address public factory;
  address[] public connectors;

  constructor(
    address _WETH,
    address _pancakeRouter,
    address _coswapRouter,
    address _bCOT,
    address _factory,
    address[] memory _connectors
  )
    public
  {
    WETH = _WETH;
    pancakeRouter = _pancakeRouter;
    coswapRouter = _coswapRouter;
    bCOT = _bCOT;
    factory = _factory;
    connectors = _connectors;
  }

  // helper for get ratio
  function getPrice(
    address _from,
    address _to,
    uint256 _amount
  )
    external
    view
    returns (uint256 value)
  {
    // if direction the same, just return amount
    if(_from == _to)
      return _amount;

    // if wrong amount, just return amount
    if(_amount == 0)
      return _amount;

    // get price
    // WRAP ETH token with weth
    address wrapETH = WETH;

    address fromAddress = _from == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
    ? wrapETH
    : _from;

    address toAddress = _to == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
    ? wrapETH
    : _to;

    // use coSwap for bCOT
    if(_from == bCOT){
     return getPriceForBCOT(toAddress, _amount);
    }
    // use Pancake only
    else{
      return getPriceFromPancake(
        fromAddress,
        toAddress,
        _amount
      );
    }
  }

  // helper for get ratio between pancake assets
  function getPriceFromPancake(
    address fromAddress,
    address toAddress,
    uint256 _amount
  )
    internal
    view
    returns (uint256 value)
  {
    // if pair exits get rate between this pair
    if(Factory(factory).getPair(fromAddress, toAddress) != address(0)){
      address[] memory path = new address[](2);
      path[0] = fromAddress;
      path[1] = toAddress;

      return routerRatio(path, _amount, pancakeRouter);
    }
    // else get connector
    else{
      address connector = findConnector(toAddress);
      require(connector != address(0), "0 connector");
      address[] memory path = new address[](3);
      path[0] = fromAddress;
      path[1] = connector;
      path[2] = toAddress;

      return routerRatio(path, _amount, pancakeRouter);
    }
  }

  function getPriceForBCOT(address toAddress, uint256 _amount)
    internal
    view
    returns(uint256)
  {
    // get bCOT in WETH from coswap
    address[] memory path = new address[](2);
    path[0] = bCOT;
    path[1] = WETH;

    uint256 bCOTinWETH = routerRatio(path, _amount, coswapRouter);

    // if toAddress == weth just return weth result
    if(toAddress == WETH){
      return bCOTinWETH;
    }
    // else convert weth result to toAddress via Pancake
    else{
      return getPriceFromPancake(
        WETH,
        toAddress,
        bCOTinWETH
      );
    }
  }

  // helper for find common connectors between tokens
  function findConnector(address _to)
    public
    view
    returns (address connector)
  {
    // cache storage vars in memory for safe gas
    address _factoryCached = factory;
    uint256 _lengthCached = connectors.length;

    for(uint i =0; i< _lengthCached; i++){
      address pair = Factory(_factoryCached).getPair(_to, connectors[i]);
      if(pair != address(0))
         return connectors[i];
    }

    return address(0);
  }

  // helper for get price from router
  function routerRatio(address[] memory path, uint256 fromAmount, address router)
    public
    view
    returns (uint256)
  {
    uint256[] memory res = Router(router).getAmountsOut(fromAmount, path);
    return res[1];
  }

  // owner can add common connectors
  function addConnector(address connector) external onlyOwner {
    connectors.push(connector);
  }
}
