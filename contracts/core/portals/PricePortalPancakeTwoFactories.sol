import "../interfaces/IDecimals.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../uniswap/interfaces/IUniswapV2Router.sol";
import "../../zeppelin-solidity/contracts/access/Ownable.sol";

interface Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}


contract PricePortalPancakeTwoFactories is Ownable {
  address public WETH;
  address public pancakeRouterA;
  address public pancakeRouterB;
  address public coswapRouter;
  address public bCOT;
  address public factoryA;
  address public factoryB;
  address[] public connectors;

  constructor(
    address _WETH,
    address _pancakeRouterA,
    address _pancakeRouterB,
    address _coswapRouter,
    address _bCOT,
    address[] memory _connectors
  )
    public
  {
    WETH = _WETH;
    pancakeRouterA = _pancakeRouterA;
    pancakeRouterB = _pancakeRouterB;
    coswapRouter = _coswapRouter;
    bCOT = _bCOT;
    factoryA = IUniswapV2Router(_pancakeRouterA).factory();
    factoryB = IUniswapV2Router(_pancakeRouterB).factory();
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
    // if pair exits in factory A get rate between this pair
    if(Factory(factoryA).getPair(fromAddress, toAddress) != address(0)){
      address[] memory path = new address[](2);
      path[0] = fromAddress;
      path[1] = toAddress;

      return routerRatio(path, _amount, pancakeRouterA);
    }
    // else if pair exits in factory B get rate between this pair
    else if(Factory(factoryB).getPair(fromAddress, toAddress) != address(0)){
      address[] memory path = new address[](2);
      path[0] = fromAddress;
      path[1] = toAddress;

      return routerRatio(path, _amount, pancakeRouterB);
    }
    // else get price via common connector
    else{
      (address connector, address router) = findConnector(toAddress);
      require(connector != address(0), "0 connector");
      address[] memory path = new address[](3);
      path[0] = fromAddress;
      path[1] = connector;
      path[2] = toAddress;

      return routerRatio(path, _amount, router);
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
    returns (address, address)
  {
    // cache storage vars in memory for safe gas
    address _factoryACached = factoryA;
    address _factoryBCached = factoryB;

    uint256 _lengthCached = connectors.length;

    for(uint i =0; i< _lengthCached; i++){
      // if exist on factory A return
      if(Factory(_factoryACached).getPair(_to, connectors[i]) != address(0))
        return (connectors[i], pancakeRouterA);


      // else check on factory B
      if(Factory(_factoryBCached).getPair(_to, connectors[i]) != address(0)){
        return (connectors[i], pancakeRouterB);
      }
    }

    return(address(0), address(0));
  }

  // helper for get price from router
  function routerRatio(address[] memory path, uint256 fromAmount, address router)
    public
    view
    returns (uint256)
  {
    uint256[] memory res = IUniswapV2Router(router).getAmountsOut(fromAmount, path);
    return res[1];
  }

  // owner can add common connectors
  function addConnector(address connector) external onlyOwner {
    connectors.push(connector);
  }
}
