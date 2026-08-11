# Remember Me / Conditional Auto-Login

## Problem

`AuthLocalDatasource` always persists the session on login, and `AppStarted`
always tries to restore it — so the app auto-logs-in on every launch with no
way to opt out. We want a "Remember me" checkbox on the login form that
controls whether the session is persisted, so auto-login only happens when
the user asked for it.

## Behavior

- Login form gains a "Remember me" `Checkbox`/`CheckboxListTile`, **checked
  by default**.
- On submit, the checked state is threaded through
  `LoginRequested` → `LoginUsecase` → `AuthRepository.login` →
  `AuthLocalDatasource`.
- If checked: session JSON is persisted as today (`saveSession`), so the next
  `AppStarted` restores it and skips the login page.
- If unchecked: no session is persisted (`clearSession` is called instead,
  wiping any previously-remembered session too), so the app stays logged in
  only for the current run — the *next* launch always shows the login page.
- `RestoreSessionUsecase` / `AuthGate` logic is unchanged: it still just
  checks "is there a stored session?" — the new behavior lives entirely in
  what gets stored at login time.

## Changes

- `AuthLocalDatasource`: no signature change needed — callers decide whether
  to call `saveSession` or `clearSession`.
- `AuthRepository.login` / `AuthRepositoryImpl.login` / `LoginUsecase.call`:
  add a required `rememberMe` bool param.
- `LoginRequested` event: add `rememberMe` field.
- `AuthBloc._onLoginRequested`: pass `event.rememberMe` through to the
  usecase.
- `LoginPage`: add checkbox state (default `true`), pass it in the
  dispatched `LoginRequested`.

## Out of scope

- No "remember username" (prefilling the username field) — only whether the
  session survives a restart.
- No change to logout behavior (`clearSession` already runs on logout).
