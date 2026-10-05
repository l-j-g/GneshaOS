# Nix style

These rules apply to repository-owned Nix. Preserve vendored skill references
and generated hardware files. Apply improvements to code touched by a task;
keep unrelated cleanup separate. AGENTS.md governs validation and activation.

- Keep two-space indentation and existing formatting; use the flake's `nixfmt`
  formatter when formatting is needed.
- Use explicit names (`pkgs.git`, `lib.mkIf`), or narrowly scoped
  `inherit (pkgs) git;` bindings. Avoid `with`; preserve ordered lists rather
  than converting them through `builtins.attrValues`.
- Prefer `let ... in` for shared bindings over `rec`. When self-reference is
  necessary, name the attribute set explicitly and check for recursion.
- Quote URLs. Leave ordinary attribute identifiers unquoted; quote names that
  require it, such as `".config/foo"`.
- Use locked flake inputs and passed arguments, rather than `<nixpkgs>` or
  dependencies on ambient `NIX_PATH`. For explicit Nixpkgs imports, supply
  both `config` and `overlays`, including empty values when appropriate.
- `//` replaces overlapping attributes shallowly. Use `lib.recursiveUpdate`
  when nested data must be merged. For NixOS/Home Manager options, use module
  definitions and option merge semantics, not ad hoc attribute-set updates.
- When packaging a local source directory whose basename could affect its
  store name, use `builtins.path { path = ./.; name = "fixed-name"; }`, or a
  suitable named source filter. Do not rewrite every existing source path.
- Prefer declarative options and focused modules; keep machine values in
  `system-parameters.nix` and literal desktop preferences in `home/variables.nix`.

## References

[nix.dev best practices](https://nix.dev/guides/best-practices) is the primary
reference for scope, reproducibility, and attribute-set updates.
[Idiomatic Nix](https://saylesss88.github.io/idiomatic_nix.html) is supplementary
reading; its interactive REPL server is not a repository requirement. Examples
using lookup paths or `attrValues` must be adapted to the rules above.
