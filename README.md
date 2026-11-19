# NoisGate — The Agent ID Gate

NoisGate is an on-chain access gate for **Binance Agent ID** holders on BNB Smart Chain,
built for the Binance Wallet × BNB Chain **Agent ID Hackathon**.

Only a wallet holding a Binance Agent ID (a `.ai` name) can claim the **Nois Gate Badge** —
a soulbound (non-transferable) ERC-721, one per wallet. Badge holders can **check in once per
day** on-chain; the contract records total check-ins and consecutive-day streaks.

## Why

Agent ID is a KYC-bound, non-transferable on-chain identity — one per person. That makes it a
natural Sybil-resistant access layer: a project can offer perks, allowlists, or participation
rights to *verified unique agents* without collecting any personal data. NoisGate is a minimal,
auditable reference implementation of that pattern: a gate, a badge, and a daily heartbeat.

## How it works

1. **Hold an Agent ID** — claimable only inside the Binance app (Wallet → Agent ID banner).
2. **Claim the badge** — `claim()` checks `balanceOf(user) > 0` on the official Agent ID
   registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) and mints one soulbound badge.
3. **Check in daily** — `checkIn()` is open to badge holders once per UTC day and updates
   `checkInCount`, `currentStreak`, and `bestStreak`, emitting a `CheckIn` event.

## Safety by design

- The contract **never takes custody of user assets** and **never requests token approvals**
  (every approval/transfer function reverts — the badge is soulbound).
- No web QR-code login, no pairing codes, no seed phrases — interaction happens only through
  the visitor's own wallet, with every transaction shown and confirmed by the user.
- No mint-for-others, no pause, no tax, no treasury, no upgradeability, no proxy.
- Deployed through the public CREATE2 factory, so the contract's `owner` is the factory
  address itself: **no admin key exists** that could change the metadata URI or ownership
  after deployment. The badge metadata is a self-contained data URI (embedded SVG).

## Contract

- **NoisGate (BNB Smart Chain):** `0xdbbC0362993BeedA917ba961D4BDF092189b6620`
- **Agent ID registry (read-only gate):** `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- Source: `contracts/NoisGate.sol` (MIT, Solidity 0.8.26, no external dependencies)

## Build & test

```bash
npm i
node compile.mjs   # solc-js → build/NoisGate.json
node test.mjs      # ganache local chain, 17 assertions (gate, soulbound, streaks)
```

## Interaction (any Web3 wallet on BSC)

- `claim()` — selector `0x4e71d92d`
- `checkIn()` — selector `0x183ff085`
- Views: `hasBadge(address)`, `badgeOf(address)`, `checkInCount(address)`,
  `currentStreak(address)`, `bestStreak(address)`, `canCheckIn(address)`, `totalClaimed()`

*NoisGate is an independent project. It is not affiliated with or endorsed by Binance;
"Binance Agent ID" is referenced descriptively only.*
