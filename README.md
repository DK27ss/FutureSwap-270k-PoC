# FutureSwap 270k PoC

## Summary

On Ethereum mainnet, an attacker exploited a critical vulnerability in FutureSwap governance system to drain **$269,681.73 USDC** from `38 EOA`, the attack leveraged a flashloan to temporarily acquire voting power, manipulate governance permissions, and extract user funds (EOA) within the span of two transactions.

| Metric | Value |
|--------|-------|
| **Date** | Block 24026876 - 24027379 |
| **Total Loss** | $269,681.73 USDC |
| **Victims** | 38 user accounts |
| **Attack Type** | Flash Loan Governance Attack |

---

## Attack Overview

### Key Addresses

| Contract | Address | Role |
|----------|---------|------|
| Attacker Contract | `0xBc59f04fA5E5936cf49991A268832714F17bFFA7` | Attack orchestrator |
| Attacker Wallet | `0xCD7C839C6814234601fE7719dA21a980c1a8184E` | Funds recipient |
| FutureSwap Wallet | `0xd1Ed35A3Ee043683A1833509dE8f2C1A0d8777B7` | Victim contract holding user funds |
| Registry | `0x3659ae5f9b009603a4900891aABEF828C8350df1` | Access control (compromised) |
| FST Token | `0x0E192d382a36De7011F795Acc4391Cd302003606` | Governance token |
| Uniswap V2 Pair | `0x88AE9E1625CfCbd128B89e7F037EaaF6a7cC9666` | Flash loan source (FST/WETH) |
| Wrapped USDC | `0x91a154F9AD33da7e889C4b6fE4A9F9C3Fc6B6081` | Token drained |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | Final stolen asset |

---

## Attack Timeline

```
Block 24026875                         Block 24026876                         Block 24027379
     |                                      |                                      |
     v                                      v                                      v
+--------------------+              +--------------------+              +--------------------+
|   BEFORE ATTACK    |              |     PHASE 1        |              |     PHASE 2        |
+--------------------+              +--------------------+              +--------------------+
| hasWalletAccess:   |              | Flash Loan FST     |              | Drain all funds    |
|   FALSE            |   -------->  | Vote for access    |   -------->  | 38 victims         |
| Attacker USDC: 0   |              | Repay loan         |              | +269,681 USDC      |
| Wallet: 315,981    |              | hasWalletAccess:   |              | Wallet: 0 USDC     |
|   wUSDC            |              |   TRUE             |              |                    |
+--------------------+              +--------------------+              +--------------------+
                                           |
                                           | ~503 blocks (~1.7 hours)
                                           v
```

<img width="1544" height="361" alt="image" src="https://github.com/user-attachments/assets/fbdca0bb-ba67-46c5-b9e8-00b82db73503" />

### Detailed Timeline

| Block | Event | State Change |
|-------|-------|--------------|
| 24026875 | Pre-attack state | `hasWalletAccess[attacker] = false` |
| **24026876** | **Phase 1: Governance Manipulation** | `hasWalletAccess[attacker] = true` |
| 24026877 - 24027378 | Waiting period (~503 blocks) | No change |
| **24027379** | **Phase 2: Fund Extraction** | 269,681 USDC stolen |

---

## Analysis

### Phase 1: Governance Manipulation (Block 24026876)

The attacker executed a flash loan governance attack in a single atomic transaction:

```                                               
1. FLASH LOAN                                                  
     ├── Source: Uniswap V2 Pair (FST/WETH)                     
     ├── Amount: ~100,000 FST tokens                            
     └── Reserve available: 5,297,492 FST                       
                                                                 
2. GOVERNANCE VOTE                                             
     ├── Use borrowed FST as voting power                       
     ├── Call governance to modify Registry                     
     └── Grant hasWalletAccess to attacker contract             
                                                                 
3. REPAY FLASH LOAN                                            
     ├── Return 100,000 FST + 0.3% fee                          
     └── Transaction completes successfully                     
                                                                 
RESULT: hasWalletAccess[attackerContract] = TRUE              
```

After the transaction, the attacker FST balance was only `165 FST` (likely leftover from fee calculations), proving the flashloan was fully repaid.

### Phase 2: Fund Extraction (Block 24027379)

With `hasWalletAccess` granted, the attacker called `sendFundsToExternalAccount()` 38 times in a single transaction:

```solidity
function sendFundsToExternalAccount(
    address tokenAsset,    // wUSDC
    address from,          // victim user account
    address to,            // attacker wallet
    uint256 amount         // amount to steal
) external {
    // Check if caller has wallet access
    require(registry.hasWalletAccess(msg.sender), "No access");

    // Unwrap wUSDC to USDC
    IWrappedToken(tokenAsset).unwrap(amount);

    // Transfer USDC to attacker
    IERC20(USDC).transfer(to, amount);
}
```

**Attack Flow**
```
sendFundsToExternalAccount(wUSDC, victim, attacker, amount)
    │
    ├── 1. Registry.hasWalletAccess(attackerContract) → TRUE ✓
    │
    ├── 2. wUSDC.unwrap(amount)
    │       ├── Burn wUSDC from FutureSwap Wallet
    │       └── Release USDC to FutureSwap Wallet
    │
    └── 3. USDC.transfer(attackerWallet, amount)
            └── Funds sent to attacker
```


### Stolen Amounts by EOA

| Victim # | Address | Amount (USDC) |
|----------|---------|---------------|
| 1 | `0x119cBaD90c38eAC1F2De5B6d854Af4dbDf587154` | $8,633.42 |
| 2 | `0x28aC9E4EECa87b5310Cb64fbE8Ff22F498Deae07` | $3,392.79 |
| 3 | `0xa1F956C6F5AAE538CD8b330f1C4E8Da0Bb60C3D0` | $4,427.05 |
| 4 | `0x7cd7A5a66d3cd2F13559d7F8a052Fa6014e07d35` | $1,465.30 |
| 5 | `0x11d0Cb5C690bC838eFc52C621F6B48040dd000F7` | $1,758.57 |
| 6 | `0xf8523151211e6cFB2D285b9B92F2eE517722253B` | $10,099.09 |
| 7 | `0x20017a30D3156D4005bDA08C40Acda0A6aE209B1` | $16,088.27 |
| 8 | `0xfaD695eFD57aD18eA64bC45eB2f60d9e38bD436d` | $1,000.00 |
| 9 | `0x0b55491245F552Ab688F495E2e39283e982490c9` | $1,515.73 |
| 10 | `0xa942141E68013eF85e0AB54A448611dc6D8Bc1f3` | $2,026.21 |
| 11 | `0x4D1467C312a83794c99b9Db678DfdfA743394EF7` | $29,709.69 |
| 12 | `0x050cEA859b5A93Ac7Bd4db4572FB7d90b7c63CAC` | $1,254.13 |
| 13 | `0xD965952823153E5CBc611be87e8322cfc329f056` | $40,187.81 |
| 14 | `0xa5b8B83EFEd000C9F36D3ae3F19E1ab0542Cf3Af` | $1,752.02 |
| 15 | `0x869CAdbD7718e1e8dDd0dF2a98C04547546633D7` | $1,922.39 |
| 16 | `0xd30391E21741C54c32987bCfcA3D880E6D261Cb0` | $1,289.09 |
| 17 | `0x76f1487D7d3f7e94c1582f0EB77AE78b283a5af4` | $1,127.76 |
| 18 | `0x7e703E579159c033913046086807d8AC84B633fB` | $1,086.51 |
| 19 | `0xF71D161FdC3895F21612D79f15Aa819b7A3d296a` | $1,141.56 |
| 20 | `0xd1083574E4Ab99F4d56F49CC646308A73d835f2e` | $1,601.94 |
| 21 | `0x5F9E3E6C76760Ce49fBd87E857fc18EBB7527584` | $5,419.16 |
| 22 | `0xB60704D2cd7dcD1468675A68F4EC43791CE35EF9` | $22,436.60 |
| 23 | `0x4FA64F4aA9C4BAF921C8896461b10e7F3da7DB68` | $3,252.53 |
| 24 | `0xE7304bA0f157f2Ade94015934284b6704BC72911` | $4,806.24 |
| 25 | `0x057F8707F317023dB00518f3bb646136be909dfd` | $1,720.83 |
| 26 | `0xbcc3bFdc4bCe4BebBaAE2D8e143D6D6C61Eb6070` | $2,972.89 |
| 27 | `0xF1A0c1723b4791638382F479C16222De4201f9c2` | $1,054.25 |
| 28 | `0x46EEA8D5b37D2Db51f35c1bC8C50CBf80fb0fFE5` | $1,919.01 |
| 29 | `0xdc3B2DCE95eBd1E7C18eAa37780D10d240146660` | $1,335.34 |
| 30 | `0x762D8C60cA00607A705172D2cADA3d3F2BD5D07e` | $2,469.26 |
| 31 | `0xB1AdceddB2941033a090dD166a462fe1c2029484` | $4,785.13 |
| 32 | `0xa35d91b3852cc0E74FB1C0f095DD17eC6578104e` | $11,400.09 |
| 33 | `0xFef37Be95Be608Ed7277F777d8BA877aD70Df125` | $1,651.26 |
| 34 | `0xd00dc42F517e0b49D1c735EBA6AeeDe8642D6380` | $54,948.80 |
| 35 | `0xBA19BA5233b49794c33f01654e99A60E579E6f29` | $5,495.02 |
| 36 | `0xAB79b0b3ad3674403D8F18fF279F7d8A85822976` | $4,976.36 |
| 37 | `0x0d224c8D7CCD8Eb98779B7a262558d8D7590A65C` | $5,140.58 |
| 38 | `0xf1Ecc163903FB69Cce46D408E171C89EB7Ca1899` | $2,419.03 |
| **Total** | **38 victims** | **$269,681.73** |

---

### Root Cause

The attack exploited four critical weaknesses in FutureSwap governance design:

```
1. NO TIMELOCK                                                 
     └── Governance changes took effect IMMEDIATELY              
         No delay between vote and execution                     
                                                                 
2. NO SNAPSHOT VOTING                                          
     └── Voting power checked at EXECUTION time                  
         Not at proposal creation time                           
         Allows flash-loaned tokens to vote                      
                                                                 
3. FLASHLOAN VULNERABLE                                       
     └── No protection against borrowed voting power             
         5.3M FST available in Uniswap for flash loans          
                                                                 
4. INSUFFICIENT QUORUM                                         
     └── Quorum too low or non-existent                         
         Single actor could pass proposals                       
```

---

## References

- Attack Transaction (Phase 1): Block 24026876
- Attack Transaction (Phase 2): Block 24027379
- [Attack TX](https://app.blocksec.com/explorer/tx/eth/0x39e584cdb52adf6b2ed5bb44bfda0e1b254cb0a3925911cc33d842feaf0a8b95)

---

## Trace Summary

```
Attacker Contract: 0xBc59f04fA5E5936cf49991A268832714F17bFFA7
    │
    ├── Block 24026876: Governance Manipulation
    │   ├── Flash loan 100,000 FST from Uniswap
    │   ├── Vote to grant hasWalletAccess
    │   └── Repay flash loan
    │
    └── Block 24027379: Fund Drainage
        └── For each of 38 victims:
            ├── sendFundsToExternalAccount(wUSDC, victim, attacker, amount)
            │   ├── Registry.hasWalletAccess(attacker) → TRUE
            │   ├── wUSDC.unwrap(amount) → USDC released
            │   └── USDC.transfer(attackerWallet, amount)
            └── Total stolen: $269,681.73 USDC
```
