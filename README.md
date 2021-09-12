# Run tests

```
NOTE: in separate console

0) npm i
1) npm run ganache  
2) truffle test
```

# Updates

```
1) Add role swaper which can trade, pool and call defi protocols.
2) Fix manager take cut for case manager take cut on the best profit period when profit go up then go down.
3) Optimize gas (remove or cache global vars in functions), for funds with 5-10 and more tokens gas now in n x less.
4) Fund creator can change fund name.
5) Add any fund asset type.
6) Remove Pools and Defi call
7) Remove tokens type stotage track (because we use for now only erc20)
8) Protect manager takeCut from flash loan atack
```



# Mainent deploy note

```
Don't forget add new addresses to new permittedAddresses contract
Don't forget set latest 1inch contract
```

# Addresses

```
1INCH Proto

0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e


1INCH ETH

0x11111254369792b2Ca5d084aB5eEA397cA8fa48B


Uniswap v2 router

0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D


WETH/COT UNI v2 pool token

0x1C29181AF7dE928d44Ec44F025FF1a6aC84e407e


COT Token

0x5c872500c00565505F3624AB435c222E558E9ff8


Convert portal

0x42c5f95e15eE6a236722248Daf47909a3561d88e

https://etherscan.io/tx/0x1b3f2d65a7d23a81c52c0f0c684a3813168ed62bdc595b38091e14e1c9b6372e


Stake

0x22053735Fc5a6a69e782d8f5B41D239ECa24630c

https://etherscan.io/tx/0x0310fc81a1614537496271cd88b6c571b3b72aaa9ed44aa24897a5ad8d921755





PermittedAddresses

0x9674ce5043606eCEE025240B7EF78fe76C8c75A6

https://etherscan.io/tx/0x97a0943b442ad18cb94b1a996bd08b7799ce59361ccbba2d76195188f5011c7d



MerkleTree

0x992F6c414A6DA6A7470dfB9D61eFc6639e9fbb0E

https://etherscan.io/tx/0xe91ad57fdab82bfea08d4382e8fea7f116dd237783493d4f722c86157ec46397
```
