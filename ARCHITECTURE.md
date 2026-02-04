# Blizzard Architecture & Workflow

## System Overview

Blizzard is a decentralized validation system for AI agents on the Avalanche C-Chain, featuring a multi-layer architecture with strong anti-Sybil protections and proof-of-work mechanisms.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Blizzard System Architecture                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌──────────────────┐    ┌──────────────────────┐   │
│  │   MCP (X402)    │    │   A2A Protocol   │    │   Agent Identity     │   │
│  │ Wallet Integration│    │ Communication    │    │   Layer (ERC-8004)   │   │
│  └─────────────────┘    └──────────────────┘    └──────────────────────┘   │
│         │                        │                           │              │
│         ▼                        ▼                           ▼              │
│  ┌─────────────────┐    ┌──────────────────┐    ┌──────────────────────┐   │
│  │Execute Agent    │    │Off-chain Task    │    │AgentIdentityNFT.sol  │   │
│  │Tasks On-Chain   │    │Delegation        │    │- Mint unique NFTs    │   │
│  └─────────────────┘    └──────────────────┘    │- Base reputation     │   │
│                                                    │- Track ownership     │   │
│                                                    └──────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    Reputation Layer                                     │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │ ReputationRegistry.sol                                            │  │ │
│  │  │ - Map agentId → reputation score                                  │  │ │
│  │  │ - Authorized caller system                                        │  │ │
│  │  │ - Safe decrease operations (no negative values)                   │  │ │
│  │  │ - Reputation gain via PoW contributions                           │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    Validation Layer                                     │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │ ValidatorRegistry.sol                                             │  │ │
│  │  │ - Minimum 1 AVAX stake requirement                                │  │ │
│  │  │ - Active validator tracking                                       │  │ │
│  │  │ - Slashing mechanism                                              │  │ │
│  │  │ - Reputation integration                                          │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │ │
│  │  │ ValidationManager.sol                                             │  │ │
│  │  │ - Submission, challenge, finalize                                 │  │ │
│  │  │ - Reputation rewards                                              │  │ │
│  │  │ - Full slashing on challenges                                     │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Workflow Process

### 1. Agent Registration & Identity Creation
```
User → AgentIdentityNFT.mint() → New Agent NFT with base reputation (0)
```

### 2. Validator Registration
```
Validator → ValidatorRegistry.registerValidator() → 
  - Stake minimum 1 AVAX
  - Pass reputation threshold check
  - Become active validator
```

### 3. Proof-of-Work Validation Cycle
```
Active Validator → ValidationManager.submit(workType, workDifficulty) → 
  ↓
Submission enters challenge period (1 day)
  ↓
If challenged → Validator gets slashed (full stake) & reputation penalty
  ↓
If not challenged after 1 day → Validator gets reputation reward based on work performed
```

## Anti-Sybil Protection Mechanisms

### Economic Barriers
- **Minimum Stake**: 1 AVAX required to become validator
- **Reputation Threshold**: Must have positive reputation to register/remain active
- **Slashing Penalties**: Full stake loss on invalid submissions

### Proof-of-Work Requirements
- **Work Verification**: Submissions must represent actual work performed
- **Difficulty Scaling**: Higher difficulty work yields greater reputation rewards
- **Reputation Accumulation**: Gradual reputation building required to participate

## MCP (X402) & A2A Integration

### MCP (Managed Communication Protocol)
- **On-chain Execution**: Execute agent tasks via X402-compatible wallets
- **Task Orchestration**: Coordinate complex multi-step operations
- **Security**: Ensures proper authorization and execution

### A2A (Agent-to-Agent)
- **Off-chain Communication**: Efficient task delegation between agents
- **Reduced Costs**: Minimize on-chain transactions for routine operations
- **Scalability**: Enable complex inter-agent workflows

## Key Security Features

1. **Role-Based Access Control**: Only authorized addresses can modify critical parameters
2. **Safe Arithmetic**: All operations protected against overflow/underflow
3. **Reputation Validation**: Continuous reputation checks prevent low-reputation actors
4. **Slashing Mechanism**: Strong economic disincentive for malicious behavior
5. **Challenge Periods**: Time-bound windows for validating submissions

## Avalanche C-Chain Optimization

- **Low Latency**: ~2 second block times enable rapid validation cycles
- **Low Fees**: Cost-effective operations for micro-transactions
- **High Throughput**: Support for thousands of concurrent validators
- **Interoperability**: Easy integration with other Avalanche ecosystem projects