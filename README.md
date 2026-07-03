# Study Bridge

[![test](https://github.com/vlad17451/study-bridge/actions/workflows/test.yml/badge.svg)](https://github.com/vlad17451/study-bridge/actions/workflows/test.yml)

A cross-chain ERC20 bridge built with Hardhat and OpenZeppelin. Tokens are burned on the source chain and minted on the target chain, gated by an off-chain validator signature that is verified on-chain with `ecrecover`. The same `Bridge` contract is deployed on every participating chain; an `AcademyToken` (mintable/burnable ERC20 with role-based access) is the asset moved across chains. Access is managed with `AccessControl` (`ADMIN_ROLE` for configuration, `VALIDATOR_ROLE` for the signing key).

Written in 2021 as a bootcamp assignment; refreshed 2026 (build fixes, security hardening, tests, README).

> Not audited — educational/portfolio project.

## Architecture

`contracts/Bridge.sol` is the bridge. `contracts/AcademyToken.sol` is a plain ERC20 whose `mint`/`burn` are restricted to `MINTER_ROLE`/`BURNER_ROLE` — the bridge holds both roles on each chain so it can burn on the source side and mint on the target side.

The flow is a burn-sign-mint state machine keyed by a hash of the transfer parameters:

```
  Source chain (Bridge A)                Target chain (Bridge B)
  =======================                =======================

  user ──swap()──▶ burn tokens
                   compute hash =
                     keccak256(recipient, symbol, amount,
                               chainFrom, chainTo, txId, address(this))
                   mark hash SWAPPED
                   emit SwapInitialized
                          │
                          ▼
              off-chain validator watches the event,
              signs the same hash with its private key
              (VALIDATOR_ROLE), returns (v, r, s)
                          │
                          ▼
  user ─────────────────────────────▶ redeem(params, v, r, s)
                                        require chainTo == currentChainId
                                        recover signer via ecrecover
                                        require signer != address(0)
                                        require signer has VALIDATOR_ROLE
                                        require hash is EMPTY (not redeemed)
                                        mark hash REDEEMED
                                        mint tokens to recipient
                                        emit SwapRedeemed
```

Each `Bridge` instance keeps its own `swapByHash` mapping, so a hash can be redeemed at most once per chain. Including `address(this)` in the hashed payload domain-separates signatures so one bridge's signature cannot be replayed against another contract, and requiring `chainTo == currentChainId` in `redeem` stops the same signature from being replayed across chains.

### Roles

- `DEFAULT_ADMIN_ROLE` / `ADMIN_ROLE` — granted to the deployer; add/activate/deactivate tokens (`addToken`, `activateTokenBySymbol`, `deactivateTokenBySymbol`) and toggle target chains (`updateChainById`).
- `VALIDATOR_ROLE` — the key(s) whose signatures `redeem` accepts.

## Getting started

Requires Node.js and npm. The test suite runs with no `.env` file.

```bash
npm install --legacy-peer-deps
npx hardhat compile
npx hardhat test
```

To deploy to a live network, copy `.env-example` to `.env` and fill `MNEMONIC` and `INFURA_API_KEY`, then use the `deploy-*` scripts in `package.json`.

The test suite (21 tests) covers token deploy/mint/burn, bridge configuration and access control (admin-only token and chain management), a full swap, a successful validator-signed redeem, and the negative paths: swap/redeem replay, inactive-token swap, wrong target chain, a non-validator signature, and a malformed (zero-recovering) signature.

## Known limitations / trust model

This is a study project. The security model is deliberately minimal and should be understood before reading the code as production-ready:

- **Single validator key = full centralization.** A single address holds `VALIDATOR_ROLE`, and its signature is the only thing standing between a user and a mint. Whoever controls that key can authorize arbitrary mints. There is no threshold, quorum, or multisig.
- **Unbounded mint authority.** The bridge holds `MINTER_ROLE` on the token with no cap, rate limit, or per-transfer ceiling. A compromised validator can mint without bound.
- **Signature malleability.** `redeem` uses raw `ecrecover` rather than a malleability-checked recovery (e.g. OpenZeppelin `ECDSA`), so a second, malleated `(v, r, s)` exists for every signature. This is not exploitable here because replay protection is keyed on the message hash, not on the signature bytes — a malleated signature recovers the same signer and hits the same already-`REDEEMED` hash.
- **`abi.encodePacked` with a dynamic `string`.** The signed payload packs a dynamic `symbol` string via `abi.encodePacked`, which has a theoretical hash-collision surface when multiple dynamic types are adjacent. Only one dynamic field is used, so collisions are not reachable in practice, but typed hashing would remove the concern.
- **No withdraw path.** The bridge exposes no function to recover ETH or tokens sent to it. Do not send funds directly to the contract.

## What production would need

A production bridge would replace the single signing key with **threshold or multisig validators** (an m-of-n committee so no single key can authorize a mint), sign **EIP-712 typed structured data** instead of `abi.encodePacked` (unambiguous encoding plus a domain separator with `chainId` and contract address baked in), and add **operational guardrails** — mint rate limits and per-transfer caps, event monitoring and alerting, and a pausable/withdraw path for incident response.
