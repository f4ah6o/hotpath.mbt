# 0005 — non-destructive build view command

Status: open

## Goal

Expose M2 rewriting through a deterministic `hotpath` build view while keeping ordinary `moon build` behavior unchanged.

## Scope

- create `.hotpath/build-view` from canonical project files
- rewrite only generated `.mbt` copies
- inject the hotpath runtime package import only into generated package metadata
- provide `view`, `build`, and `clean` commands
- delete/recreate the fixed build-view directory on every generation
- run `moon build` from the generated view for the `build` command

## Acceptance

- [ ] canonical source and `moon.pkg` files remain byte-for-byte unchanged
- [ ] stale generated files cannot survive a new build-view generation
- [ ] generated packages that contain instrumentation import `f4ah6o/hotpath/src` as `@hotpath`
- [ ] missing runtime dependency and unsupported legacy package metadata fail actionably
- [ ] a normal repository `moon build` does not invoke source instrumentation
- [ ] generated build view is checked in CI
