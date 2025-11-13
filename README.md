# Token-Gated Voting System
## A Decentralized Governance Platform with Paid Voting
**Author:** Sulphate, Tarilatei, Naomi and Emmanuel.
**Date:** November 13, 2025  
**Course/Project Submission:** WEB3 CAPSTONE GROUP PROJECT

---

### Project Overview
This is a **fully functional token-gated voting system** built on Ethereum using Solidity and Hardhat.  
Users must hold or pay with the custom **VoteToken (VOTE)** ERC-20 token to participate in governance.  
The system uses **OpenZeppelin Governor** as the base — the same framework used by major DAOs like Compound, Uniswap, and Aave — extended with **paid voting**, refunds, treasury/burn options, quorum, timelock, and emergency controls.

**Key Features:**
- Pay a fixed amount of VOTE tokens to cast a vote (e.g., 10 VOTE per vote)
- Optional free voting for token holders
- Refund if proposal is cancelled
- Weighted voting via ERC20Votes (snapshotting prevents flash loans)
- Quorum (4% default), timelock execution, pausable
- Admin controls + AccessControl roles
- Full test suite + deployment script
- Simple frontend snippet for MetaMask

**Why this matters:**  
This demonstrates real-world token utility — tokens are not just speculative; they **gate influence** in governance, creating economic alignment.
