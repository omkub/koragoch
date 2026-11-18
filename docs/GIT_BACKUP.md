# GitHub Backup Workflow

Use GitHub as a versioned backup by saving clean checkpoints often.

## Version standard

Use this format for every GitHub backup tag:

`YY.M.N`

- `YY` = last two digits of the year
- `M` = month number without a leading zero
- `N` = the sequence number of the backup pushed in that month, starting at `1`

Examples:

- `26.6.1` = first backup pushed in June 2026
- `26.6.2` = second backup pushed in June 2026

Rules:

- Use the same version for the Git tag and the GitHub Release title
- Increase only `N` when you push another backup in the same month
- Keep the version tied to the actual GitHub push, not to local saves

## Daily flow

1. Check what changed.
```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' status
```

2. Stage the files you want to keep.
```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' add .
```

3. Create a commit with a clear message.
```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' commit -m "Describe the checkpoint"
```

4. Push the checkpoint to GitHub.
```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' push
```

## Before risky edits

Create a checkpoint first so you can return to it later.

```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' add .
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' commit -m "Before risky change"
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' push
```

## Find an older version

Show history:

```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' log --oneline
```

Inspect an older commit without changing the branch:

```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' checkout <commit-id>
```

Go back to the latest branch version:

```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' checkout main
```

## When the code is truly broken

If you want to move `main` itself back to an older commit, use this only when you are sure:

```powershell
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' reset --hard <commit-id>
& 'C:\Program Files\Git\cmd\git.exe' -c safe.directory='F:/oil/SchoolLeaveApp' push --force
```

This rewrites history, so use it carefully.
