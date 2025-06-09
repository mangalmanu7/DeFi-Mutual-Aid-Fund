# 🤝 DeFi Mutual Aid Fund

A decentralized mutual aid fund built on Stacks blockchain that enables community-driven emergency financial assistance through transparent, rules-based disbursement.

## 🌟 Features

- 💰 **Community Contributions**: Anyone can contribute STX to build the mutual aid fund
- 🆘 **Emergency Requests**: Community members can request financial assistance
- 🗳️ **Democratic Voting**: Contributors vote on aid requests based on their contribution level
- ⏰ **Time-bound Decisions**: Voting periods ensure timely processing of requests
- 🔍 **Full Transparency**: All transactions and votes are publicly visible on-chain
- 🛡️ **Secure & Trustless**: Smart contract handles all fund management automatically

## 🚀 How It Works

### For Contributors
1. **Contribute STX** to the mutual aid fund (minimum 1 STX)
2. **Receive voting power** based on your contribution level
3. **Vote on aid requests** from community members
4. **Help decide** who receives emergency assistance

### For Aid Seekers
1. **Submit a request** with the amount needed and reason
2. **Community votes** on your request for 144 blocks (~24 hours)
3. **Automatic disbursement** if 60%+ approval is reached
4. **Receive STX directly** to your wallet if approved

## 💡 Voting Power System

| Contribution Level | Voting Power |
|-------------------|--------------|
| 1+ STX | 1 vote |
| 5+ STX | 10 votes |
| 50+ STX | 50 votes |
| 100+ STX | 100 votes |

## 📋 Usage Instructions

### Contributing to the Fund
```clarity
(contract-call? .mutual-aid-fund contribute u5000000) ;; Contribute 5 STX
```

### Requesting Aid
```clarity
(contract-call? .mutual-aid-fund request-aid u2000000 "Medical emergency - need funds for treatment")
```

### Voting on Requests
```clarity
(contract-call? .mutual-aid-fund vote-on-request u1 true) ;; Vote YES on request #1
(contract-call? .mutual-aid-fund vote-on-request u1 false) ;; Vote NO on request #1
```

### Processing Completed Votes
```clarity
(contract-call? .mutual-aid-fund process-request u1) ;; Process request #1 after voting period
```

## 🔍 Read-Only Functions

### Check Fund Status
```clarity
(contract-call? .mutual-aid-fund get-fund-stats)
(contract-call? .mutual-aid-fund get-fund-balance)
```

### View Request Details
```clarity
(contract-call? .mutual-aid-fund get-request-details u1)
(contract-call? .mutual-aid-fund get-request-approval-rate u1)
(contract-call? .mutual-aid-fund is-voting-active u1)
```

### Check Your Contribution
```clarity
(contract-call? .mutual-aid-fund get-contributor-info 'SP1234567890ABCDEF)
```

## ⚙️ Contract Parameters

- **Minimum Contribution**: 1 STX (1,000,000 microSTX)
- **Voting Period**: 144 blocks (~24 hours)
- **Approval Threshold**: 60% of voting power
- **Emergency Withdrawal**: Contract owner only (for security)

## 🛠️ Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Local Testing
```bash
clarinet console
```

### Deploy to Testnet
```bash
clarinet deploy --testnet
```

## 🔐 Security Features

- ✅ Input validation on all public functions
- ✅ Access control for sensitive operations
- ✅ Overflow protection on arithmetic operations
- ✅ Emergency withdrawal mechanism
- ✅ Time-bound voting to prevent stale requests

## 🤔 Use Cases

- 🏥 **Medical Emergencies**: Unexpected healthcare costs
- 🏠 **Housing Crisis**: Rent assistance or emergency repairs  
- 🍽️ **Food Security**: Temporary assistance for basic needs
- 📚 **Education**: Emergency funding for educational expenses
- 💼 **Job Loss**: Bridge funding during unemployment

## 📊 Transparency

All fund activities are recorded on-chain:
- Contribution amounts and contributors
- Aid request details and voting results
- Fund balance and disbursement history
- Voting participation and outcomes

---

*Built with ❤️ for community mutual aid on Stacks blockchain*
```

**Git Commit Message:**
```
feat: implement DeFi mutual aid fund MVP with voting and transparent disbursement
```

**GitHub Pull Request Title:**
```
🤝 Add DeFi Mutual Aid Fund Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## Summary
Implements a decentralized mutual aid fund smart contract that enables community-driven emergency financial assistance through transparent, democratic voting.

## What's Added
- **Smart Contract**: Complete Clarity implementation with contribution, voting, and disbursement logic
- **Voting System**: Contribution-weighted voting with 60% approval threshold
- **Time Management**: 24-hour voting periods with automatic processing
- **Security Features**: Input validation, access controls, and emergency mechanisms
- **Read Functions**: Comprehensive query capabilities for transparency
- **Documentation**: Complete README with usage instructions and examples

## Key Features
✅ STX contribution system with minimum thresholds  
✅ Democratic voting on aid requests  
✅ Automatic fund disbursement based on vote outcomes  
✅ Transparent on-chain record of all activities  
✅ Emergency withdrawal capability for contract security  
