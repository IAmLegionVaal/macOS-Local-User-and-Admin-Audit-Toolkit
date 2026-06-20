# macOS Local User and Admin Audit Toolkit

A read-only Bash toolkit for auditing local accounts, administrator membership, secure tokens, login history, shell access, and home-folder configuration.

## Usage

```bash
chmod +x src/macos_user_admin_audit.sh
sudo ./src/macos_user_admin_audit.sh
```

## Checks performed

- Local users and UIDs
- Administrator-group membership
- Secure-token status
- Login shell and home-folder existence
- FileVault user indicators
- Recent and failed login history
- Text, CSV, and JSON reports

## Safety

The toolkit never creates, removes, disables, unlocks, or changes users, passwords, groups, secure tokens, or FileVault settings.

## Author

Dewald Pretorius — L2 IT Support Engineer
