# ui-prompt-template.md (stub)

> Minimal stub — enough concrete rules for the check scripts to enforce.

## 1. Colors
No raw hex colors — use `--csmju-*` design tokens (see `ui-design-system.md`).

## 2. Component library
No third-party UI library besides `@csmju2030/design-system`.

## 5. Accessibility / markup hygiene
Forbidden patterns: `<div onClick=`, inline `outline: none`, and
`!important` in stylesheets.

## 8. No emoji
Product screens must not contain emoji characters.

## 9. Token storage
`access_token` must never be written to `localStorage` — use an httpOnly
cookie or in-memory storage only.
