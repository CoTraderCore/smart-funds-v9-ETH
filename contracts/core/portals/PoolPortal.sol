pragma solidity ^0.6.12;

/*
* This contract allow buy/sell pool for Bancor and Uniswap assets
* and provide ratio and addition info for pool assets
*/

import "../../zeppelin-solidity/contracts/access/Ownable.sol";
import "../../zeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../../zeppelin-solidity/contracts/math/SafeMath.sol";
import "../../uniswap/interfaces/IUniswapV2Router.sol";
import "../../uniswap/interfaces/IUniswapV2Pair.sol";

import "../interfaces/ITokensTypeStorage.sol";

contract PoolPortal is Ownable{
  using SafeMath for uint256;

  uint public version = 4;

  IUniswapV2Router public uniswapV2Router;

  // Enum
  // NOTE: You can add a new type at the end, but do not change this order
  enum PortalType { Pancake }

  // events
  event BuyPool(address poolToken, uint256 amount, address trader);
  event SellPool(address poolToken, uint256 amount, address trader);

  // Contract for handle tokens types
  ITokensTypeStorage public tokensTypes;


  /**
  * @dev contructor
  *
  * @param _uniswapV2Router          address of Uniswap V2 router
  * @param _tokensTypes              address of the ITokensTypeStorage
  */
  constructor(
    address _uniswapV2Router,
    address _tokensTypes

  )
  public
  {
    uniswapV2Router = IUniswapV2Router(_uniswapV2Router);
    tokensTypes = ITokensTypeStorage(_tokensTypes);
  }


  /**
  * @dev buy Bancor or Uniswap pool
  *
  * @param _amount             amount of pool token
  * @param _type               pool type
  * @param _poolToken          pool token address (NOTE: for Bancor type 2 don't forget extract pool address from container)
  * @param _connectorsAddress  address of pool connectors (NOTE: for Uniswap ETH should be pass in [0], ERC20 in [1])
  * @param _connectorsAmount   amount of pool connectors (NOTE: for Uniswap ETH amount should be pass in [0], ERC20 in [1])
  * @param _additionalArgs     bytes32 array for case if need pass some extra params, can be empty
  * @param _additionalData     for provide any additional data, if not used just set "0x",
  * for Bancor _additionalData[0] should be converterVersion and _additionalData[1] should be converterType
  *
  */
  function buyPool
  (
    uint256 _amount,
    uint _type,
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  payable
  returns(uint256 poolAmountReceive, uint256[] memory connectorsSpended)
  {

    // Buy Uniswap pool
    if (_type == uint(PortalType.Pancake)){
      // define spender dependse of UNI pool version
      address spender = address(uniswapV2Router);

      // approve pool tokens to Uni pool exchange
      _approvePoolConnectors(
        _connectorsAddress,
        _connectorsAmount,
        spender);

      _buyUniswapPoolV2(
        _poolToken,
        _connectorsAddress,
        _connectorsAmount,
        _additionalData
        );
      // get pool amount
      poolAmountReceive = IERC20(_poolToken).balanceOf(address(this));
      // check if we recieved pool token
      require(poolAmountReceive > 0, "ERR UNI pool received 0");
    }
    else{
      // unknown portal type
      revert("Unknown portal type");
    }

    // transfer pool token to fund
    IERC20(_poolToken).transfer(msg.sender, poolAmountReceive);

    // transfer connectors remains to fund
    // and calculate how much connectors was spended (current - remains)
    connectorsSpended = _transferPoolConnectorsRemains(
      _connectorsAddress,
      _connectorsAmount);

    // trigger event
    emit BuyPool(address(_poolToken), poolAmountReceive, msg.sender);
  }


  /**
  * @dev helper for buy pool in Uniswap network v2
  */
  function _buyUniswapPoolV2(
    address _poolToken,
    address[] calldata _connectorsAddress,
    uint256[] calldata _connectorsAmount,
    bytes calldata _additionalData
  )
   private
  {
    // set deadline
    uint256 deadline = now + 15 minutes;
    // get additional data
    (uint256 amountAMinReturn,
      uint256 amountBMinReturn) = abi.decode(_additionalData, (uint256, uint256));

    // Buy UNI V2 pool
    // ETH connector case
    if(_connectorsAddress[0] == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
      uniswapV2Router.addLiquidityETH.value(_connectorsAmount[0])(
       _connectorsAddress[1],
       _connectorsAmount[1],
       amountBMinReturn,
       amountAMinReturn,
       address(this),
       deadline
      );
    }
    // ERC20 connector case
    else{
      uniswapV2Router.addLiquidity(
        _connectorsAddress[0],
        _connectorsAddress[1],
        _connectorsAmount[0],
        _connectorsAmount[1],
        amountAMinReturn,
        amountBMinReturn,
        address(this),
        deadline
      );
    }
    // Set token type
    tokensTypes.addNewTokenType(_poolToken, "UNISWAP_POOL_V2");
  }


  /**
  * @dev helper for buying BNT or UNI pools, approve connectors from msg.sender to spender address
  * return ETH amount if connectorsAddress contains ETH address
  */
  function _approvePoolConnectors(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount,
    address spender
  )
    private
    returns(uint256 etherAmount)
  {
    // approve from portal to spender
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      if(connectorsAddress[i] != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
        // transfer from msg.sender and approve to
        _transferFromSenderAndApproveTo(
          IERC20(connectorsAddress[i]),
          connectorsAmount[i],
          spender);
      }else{
        etherAmount = connectorsAmount[i];
      }
    }
  }

  /**
  * @dev helper for buying BNT or UNI pools, transfer ERC20 tokens and ETH remains after bying pool,
  * if the balance is positive on this contract, and calculate how many assets was spent.
  */
  function _transferPoolConnectorsRemains(
    address[] memory connectorsAddress,
    uint256[] memory currentConnectorsAmount
  )
    private
    returns (uint256[] memory connectorsSpended)
  {
    // set length for connectorsSpended
    connectorsSpended = new uint256[](currentConnectorsAmount.length);

    // transfer connectors back to fund if some amount remains
    uint256 remains = 0;
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      // ERC20 case
      if(connectorsAddress[i] != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
        // check balance
        remains = IERC20(connectorsAddress[i]).balanceOf(address(this));
        // transfer ERC20
        if(remains > 0)
           IERC20(connectorsAddress[i]).transfer(msg.sender, remains);
      }
      // ETH case
      else {
        remains = address(this).balance;
        // transfer ETH
        if(remains > 0)
           (msg.sender).transfer(remains);
      }

      // calculate how many assets was spent
      connectorsSpended[i] = currentConnectorsAmount[i].sub(remains);
    }
  }


  /**
  * @dev sell Bancor or Uniswap pool
  *
  * @param _amount            amount of pool token
  * @param _type              pool type
  * @param _poolToken         pool token address
  * @param _additionalArgs    bytes32 array for case if need pass some extra params, can be empty
  * @param _additionalData    for provide any additional data, if not used just set "0x"
  */
  function sellPool
  (
    uint256 _amount,
    uint _type,
    IERC20 _poolToken,
    bytes32[] calldata _additionalArgs,
    bytes calldata _additionalData
  )
  external
  returns(
    address[] memory connectorsAddress,
    uint256[] memory connectorsAmount
  )
  {
    // sell Bancor Pool
    if (_type == uint(PortalType.Pancake)){
      // define spender dependse of UNI pool version
      address spender = address(uniswapV2Router);
      // approve pool token
      _transferFromSenderAndApproveTo(_poolToken, _amount, spender);
      // sell Uni v1 or v2 pool
      (connectorsAddress) = sellPoolViaUniswapV2(_amount, _additionalData);
      // transfer pool connectors back to fund
      connectorsAmount = transferConnectorsToSender(connectorsAddress);
    }
    else{
      revert("Unknown portal type");
    }

    emit SellPool(address(_poolToken), _amount, msg.sender);
  }


  /**
  * @dev helper for sell pool in Uniswap network v2
  */
  function sellPoolViaUniswapV2(
    uint256 _amount,
    bytes calldata _additionalData
  )
    private
    returns(address[] memory connectorsAddress)
  {
    // get additional data
    uint256 minReturnA;
    uint256 minReturnB;

    // get connectors and min return from bytes
    (connectorsAddress,
      minReturnA,
      minReturnB) = abi.decode(_additionalData, (address[], uint256, uint256));

    // get deadline
    uint256 deadline = now + 15 minutes;

    // sell pool with include eth connector
    if(connectorsAddress[0] == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
      uniswapV2Router.removeLiquidityETH(
          connectorsAddress[1],
          _amount,
          minReturnB,
          minReturnA,
          address(this),
          deadline
      );
    }
    // sell pool only with erc20 connectors
    else{
      uniswapV2Router.removeLiquidity(
          connectorsAddress[0],
          connectorsAddress[1],
          _amount,
          minReturnA,
          minReturnB,
          address(this),
          deadline
      );
    }
  }

  /**
  * @dev helper for sell Bancor and Uniswap pools
  * transfer pool connectors from sold pool back to sender
  * return array with amount of recieved connectors
  */
  function transferConnectorsToSender(address[] memory connectorsAddress)
    private
    returns(uint256[] memory connectorsAmount)
  {
    // define connectors amount length
    connectorsAmount = new uint256[](connectorsAddress.length);

    uint256 received = 0;
    // transfer connectors back to fund
    for(uint8 i = 0; i < connectorsAddress.length; i++){
      // ETH case
      if(connectorsAddress[i] == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
        // update ETH data
        received = address(this).balance;
        connectorsAmount[i] = received;
        // tarnsfer ETH
        if(received > 0)
          payable(msg.sender).transfer(received);
      }
      // ERC20 case
      else{
        // update ERC20 data
        received = IERC20(connectorsAddress[i]).balanceOf(address(this));
        connectorsAmount[i] = received;
        // transfer ERC20
        if(received > 0)
          IERC20(connectorsAddress[i]).transfer(msg.sender, received);
      }
    }
  }


  /**
  * @dev helper for get amounts for both Uniswap connectors for input amount of pool
  * for Uniswap version 2
  *
  * @param _amount         pool amount
  * @param _exchange       address of uniswap exchane
  */
  function getUniswapV2ConnectorsAmountByPoolAmount(
    uint256 _amount,
    address _exchange
  )
    public
    view
    returns(
      uint256 tokenAmountOne,
      uint256 tokenAmountTwo,
      address tokenAddressOne,
      address tokenAddressTwo
    )
  {
    tokenAddressOne = IUniswapV2Pair(_exchange).token0();
    tokenAddressTwo = IUniswapV2Pair(_exchange).token1();
    // total_liquidity exchange.totalSupply
    uint256 totalLiquidity = IERC20(_exchange).totalSupply();
    // ethAmount = amount * exchane.eth.balance / total_liquidity
    tokenAmountOne = _amount.mul(IERC20(tokenAddressOne).balanceOf(_exchange)).div(totalLiquidity);
    // ercAmount = amount * token.balanceOf(exchane) / total_liquidity
    tokenAmountTwo = _amount.mul(IERC20(tokenAddressTwo).balanceOf(_exchange)).div(totalLiquidity);
  }


  /**
  * @dev Transfers tokens to this contract and approves them to another address
  *
  * @param _source          Token to transfer and approve
  * @param _sourceAmount    The amount to transfer and approve (in _source token)
  * @param _to              Address to approve to
  */
  function _transferFromSenderAndApproveTo(IERC20 _source, uint256 _sourceAmount, address _to) private {
    require(_source.transferFrom(msg.sender, address(this), _sourceAmount));
    // reset previous approve (some ERC20 not allow do new approve if already approved)
    _source.approve(_to, 0);
    // approve
    _source.approve(_to, _sourceAmount);
  }

  // fallback payable function to receive ether from other contract addresses
  fallback() external payable {}
}
