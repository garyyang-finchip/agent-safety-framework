# Task tender fixture (vendored, unmodified)

`TaskToken.sol`, `TaskVault.sol` and `interfaces/` are copied verbatim from
https://github.com/garyyang-finchip/task-token-standard at commit
`306a8f4046560ea181b1a967c18fb378e8871528` (TASK-KERNEL v3.0) so that the ASF tender adapter tests run
against the real kernel's ABI, deadline checks (`settleBy`, `judgmentWindow`), reservation logic
and `claimUnjudged` default. They are test fixtures only; they are not part of the ASF assets.
