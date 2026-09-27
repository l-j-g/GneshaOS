# Supplemental NixOS management reference

`skills/nixos-managing/` is vendored supplemental guidance, adapted from
[michalzubkowicz/nixos-management-skill](https://github.com/michalzubkowicz/nixos-management-skill).
The imported files include an MIT license; see [`LICENSE.txt`](LICENSE.txt).

The repository history records the initial import in commit
`9be501447a7f204c3f7076a89d52c4ede3cc0025` (2026-09-24), but does not record
the exact upstream revision used. Treat upstream content as unpinned reference
material until a future update records its source revision.

Local adaptations include the repository safety precedence block in
[`SKILL.md`](SKILL.md), which requires build-only validation unless activation
is explicitly requested, and the repository-specific OpenAI agent adapter in
[`agents/openai.yaml`](agents/openai.yaml). The imported upstream operational
examples remain general and must be reconciled with `AGENTS.md` and
`.codex/skills/gneshaos-maintenance/SKILL.md` before use.
