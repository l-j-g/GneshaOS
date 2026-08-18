# NixOS modules

Reusable NixOS modules live here. They define portable behavior and options;
machine-specific choices belong under `hosts/`, while user-facing values are
passed from root `params.nix`. Keep modules declarative and avoid embedding
machine secrets or generated hardware data.
