# macOS Local User and Admin Audit Toolkit

A macOS support toolkit for auditing local accounts and correcting selected administrator-group membership issues.

## Audit script

```bash
chmod +x src/macos_user_admin_audit.sh
sudo ./src/macos_user_admin_audit.sh
```

The audit reports local users, administrator membership, secure-token status, login shell, home-folder state, FileVault user indicators and recent login history.

## Repair script

Preview an administrator membership change:

```bash
chmod +x src/macos_admin_membership_repair.sh
sudo ./src/macos_admin_membership_repair.sh \
  --add-admin \
  --user exampleuser \
  --dry-run
```

Add a local administrator:

```bash
sudo ./src/macos_admin_membership_repair.sh --add-admin --user exampleuser
```

Remove administrator membership:

```bash
sudo ./src/macos_admin_membership_repair.sh --remove-admin --user exampleuser
```

## What the repair does

- Changes membership only for an existing local interactive user.
- Refuses to modify low-UID system accounts.
- Refuses to remove the last local administrator.
- Records administrator membership before and after the change.
- Supports confirmation prompts, dry-run, logs and clear exit codes.

## Safety and limitations

The repair does not create or delete users, change passwords, alter secure tokens or modify FileVault recovery settings. Secure-token or FileVault-user repairs require an authorised administrator and Apple-supported interactive workflows.

## Author

Dewald Pretorius — L2 IT Support Engineer
