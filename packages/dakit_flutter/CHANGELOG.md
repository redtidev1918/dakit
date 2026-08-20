## 0.1.0-dev.1

- Add system-browser, app-links, and secure-storage platform adapters.
- Add the ready-to-use `DAKitOAuthClient` facade.
- Persist pending PKCE transactions for process restart recovery.
- Add native-scheduler background transfers with persistent recovery and proxy
  configuration.
- Allow the OAuth facade to use an explicit API network profile without coupling
  it to media-transfer proxy settings.
- Cancel a pending browser transaction before logging out so a late callback
  cannot silently restore the local session.
