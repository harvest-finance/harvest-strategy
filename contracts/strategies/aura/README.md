# Aura Strategy

### Types
| Reward Token | Deposit | Steps |
| ------------- | ---- | ---- |
| AURA + BAL | Non-bbaUSD | <ul> <li> Swap AURA + BAL to WETH</li> <li> Swap WETH to the Deposit Token </li> <li> Deposit the Deposit Token and Receive Underlying BPT </li> <li> Deposit BPT Token to Aura </li> </ul> |
| AURA + BAL + bbaUSD | bbaUSD | <ul> <li> Swap AURA + BAL to WETH </li> <li> Swap WETH to bbaUSD </li> <li> Deposit bbaUSD and Receive Underlying BPT </li> <li> Deposit BPT Token to Aura </li> </ul> |
| AURA + BAL + bbaUSD | Non-bbaUSD | <ul> <li> Swap AURA + BAL to WETH </li> <li> Batch Swap bbaUSD to WETH </li> <li> Swap WETH to the Deposit Token </li> <li> Deposit the Deposit Token and Receive Underlying BPT </li> <li> Deposit BPT Token to Aura </li> </ul> |

### Takeaways
* In Balancer, ComposableStablePool assets like [bbaUSD](https://etherscan.io/address/0xa13a9247ea42d743238089903570127dda72fe44#contracts) will have infinite allowance to BVault hard-coded in the contract. In this case, safeAppove will revert.