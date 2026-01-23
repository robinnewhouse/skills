---
name: fix-local-js-yaml-types
description: Fix local TypeScript compile errors about missing js-yaml types without modifying package.json by performing a clean reinstall of dependencies.
---

# Fix local js-yaml types error (no package.json changes)

When the user reports `TS7016: Could not find a declaration file for module 'js-yaml'` and says main works but their local environment is broken, follow this workflow to reset the local install **without touching package.json**.

## Steps

1. **Confirm current install state**
   - Check that `node_modules/js-yaml/dist` exists.

2. **Clean local dependencies** (no package.json edits)
   - Remove `node_modules` in the repo root.
   - Reinstall with `npm install` in the repo root only.

3. **Verify the error is gone**
   - Run `npm run check-types` and confirm it completes without the TS7016 error.

## Notes

- Do **not** run `npm install -D @types/js-yaml` or edit `package.json`/`package-lock.json`.
- If reinstall stalls or fails, suggest `npm cache clean --force` and retry, but only if needed.
