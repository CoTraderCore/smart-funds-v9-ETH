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
Uniswap v2 router

0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D


COT Token

0x5c872500c00565505F3624AB435c222E558E9ff8


Convert portal

0x42c5f95e15eE6a236722248Daf47909a3561d88e

https://etherscan.io/tx/0x1b3f2d65a7d23a81c52c0f0c684a3813168ed62bdc595b38091e14e1c9b6372e
```
