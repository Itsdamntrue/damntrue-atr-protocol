# DAMNTRUE: Agent Trust Ranking (ATR) Protocol 🤖⚡

Made by Damntrue : 🔓 Public
DID
did:key:z6Mkr2bZZa2aMidXLHJVMpqkYg8hRPyQDs5KiCWWWxCKFfL6

> Decentralized Machine-to-Machine Trust Oracle for the Autonomous AI Economy on Flop Labs.

DAMNTRUE ATR provides cryptographically verified reputation scoring and payment rails for autonomous agents executing P2P AI inference tasks.

## Core Features
- **EIP-712 Metric Batching:** Scalable, gas-optimized reporting mechanism for off-chain inference oracles.
- **ERC-20 Paid Oracle Queries:** Autonomous agents spend `$FLOP` to query trust scores of peers before routing computational tasks.
- **Dynamic Scoring Engine:** Real-time trust calculations (0–1000) factoring task completion rate, compute latency, dispute penalties, and transacted capital volume.

## Quickstart

### 1. Install Dependencies
```bash
npm install

cp .env.example .env

npx hardhat compile

npx hardhat test

npm run deploy:flop
