# Run tests

```
NOTE: in separate console

0) npm i
1) npm run ganache  
2) truffle test
```


# Mainent deploy note

```
Don't forget set new pool, defi and exchange, portals to Tokens Type storage contract as permitted to write
Don't forget add new addresses to new permittedAddresses contract
Don't forget set latest 1inch contract
```

# Updates in v9
```
1) Add role swaper which can trade, pool and call defi protocols.
2) Fix manager take cut for case manager take cut on the best profit period when profit go up then go down.
3) Optimize gas (remove or cache global vars in functions), for funds with 5-10 and more tokens gas now in n x less.
4) Fund creator can change fund name.
5) Add any fund asset type.
```


# Possible issue

```
Exchange and Pool Portals v7 not has incompatibility with older versions,
so frontend should support different version of portals
```


# ADDRESSES

```
0.6.12+commit.27d51765

optimization true 200

WETH

0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c

DAI BSC

0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3

CoSwap Router

0x82d45a1cCaBE624eEB275B9d3DAA177aFf82953f


Pancake Router A

0x10ED43C718714eb63d5aA57B78B54704E256024E


Pancake Router B

0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F


Pancake Factory A

0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73

Pancake Factory B

0xBCfCcbde45cE874adCB698cC183deBcF17952812


1inch Router

0x11111112542D85B3EF69AE05771c2dCCff4fAa26


1inch price rate

0xe26A18b00E4827eD86bc136B2c1e95D5ae115edD


ROOT

0x07596b59c8f5791b45713f921d0cabedc1d8012cd3eb1474552472735d476def


Permitted address

0x992F6c414A6DA6A7470dfB9D61eFc6639e9fbb0E


Merkle Root contract

0x3344573A8b164D9ed32a11a5A9C6326dDB3dC298


Tokens Type storage

0x666CAe17452Cf2112eF1479943099320AFD16d47

Price Portal

0x0D038FB3b78AEB931AC0A8d890F9E5A12A2b96B3


Pool Portal 1 inch

0x2b4ba0A92CcC11E839d1928ae73b34E7aaC2C040

Price Portal Pancake Two Factories

0xaBbD442181DE83c54c4Cf14BbF5C03fBda8887df

Price Portal Pancake (NEW)

0xE8eF35b4E165C98075453846461cc439BfF0aE99

Price Portal Pancake (OLD)

0x7eb09Fbd33b87808512E7EE20b68933876862f9f


Defi Portal (NOT IMPLEMENTED)

0x6d85Dd4672AFad01a28bdfA8b4323bE910999954


New Exchange Portal

0x5f0b0f12718c256a0E172d199AA50F7456fd24AA

ExchangePortalLight (NEW)

0x169331EC668f3ACa19feb89AC300C4b291c4C586


ExchangePortalLight (OLD)

0x34A872911a7a3C7112F4821cfaAe42660D24AEE9


SmartFundETHFactory

0xc2cec1dd326467186Dd821c9EB1F81937acB7Be3


SmartFundERC20Factory

0x2c8aA3148aa50bbfedF711C095DE16975896D280


SmartFundRegistry

0x759563F3A0f51A202e504BE5Ea3DeF0D3b4e6933


MockExchangePortalPrice

0xe81F3fF8c7D6F2E3f19A7872fD32D5EAC5491C91

```
