# Common Vulnerability Patterns

Quick reference for detecting security issues in code changes.

## General Patterns
- **Reentrancy:** State changes after external calls (CEI pattern violation)
- **Unchecked inputs:** Missing validation on user-provided data
- **Race conditions:** Time-of-check to time-of-use (TOCTOU)
- **Privilege escalation:** Missing or weak authorization checks
- **Injection:** SQL, command, LDAP, XPath injection
- **Path traversal:** Unvalidated file paths
- **Misuse of cryptography:** Weak algorithms, hardcoded keys, predictable randomness

## Security Regressions
Previously removed code re-added. Detection: `git log -S "pattern" --all --grep="security\|fix\|CVE"`. Red flags: commit contains "security"/"fix"/"CVE", removed <6 months ago, no explanation in current PR.

## Missing Validation
Removed `require`/`assert`/`check` without replacement. Detection: `git diff <range> | grep "^-.*require"`. Ask: moved elsewhere? Redundant? Exposes vulnerability?

## Double Decrease/Increase
Same accounting operation twice for same event. Look for two state updates in related functions for same logical action.

## Underflow/Overflow
Arithmetic without SafeMath or checks. Look for unchecked blocks in Solidity >=0.8.0 or raw math in <0.8.0.

## Access Control Bypass
Removed or relaxed permission checks. Detection: `git diff <range> | grep "^-.*onlyOwner"`. Who can now call this function? New trust model?

## Race Conditions / Front-Running
State-dependent logic without commit-reveal or timelocks. Two-step processes vulnerable to front-running between steps.

## Unchecked Return Values
External call without checking success. Silent failures lead to inconsistent state.

## Denial of Service
Unbounded loops over user-controlled arrays. Critical functions depending on external call success.

## Quick Detection Commands
```bash
git diff <range> | grep "^-" | grep -E "require|assert|revert"   # removed checks
git diff <range> | grep "^+" | grep -E "\.call|\.delegatecall"   # new external calls
git diff <range> | grep -E "onlyOwner|onlyAdmin|internal|private|public|external"  # access changes
```
