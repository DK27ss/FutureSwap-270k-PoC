# FutureSwap 270k PoC

## Summary

On Ethereum mainnet, an attacker exploited a critical vulnerability in FutureSwap governance system to drain **$269,681.73 USDC** from `38 EOA`. The attack leveraged a flashloan to temporarily acquire voting power, manipulate governance permissions, and extract user funds—all within the span of two transactions.

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
| 1 | `0x119cBaD9...` | $8,633.42 |
| 2 | `0x28aC9E4E...` | $3,392.79 |
| 3 | `0xa1F956C6...` | $4,427.05 |
| 4 | `0x7cd7A5a6...` | $1,465.30 |
| 5 | `0x11d0Cb5C...` | $1,758.57 |
| 6 | `0xf8523151...` | $10,099.09 |
| 7 | `0x20017a30...` | $16,088.27 |
| 8 | `0xfaD695eF...` | $1,000.00 |
| 9 | `0x4D1467C3...` | $29,709.69 |
| 10 | `0xD9659528...` | $40,187.81 |
| ... | ... | ... |
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
