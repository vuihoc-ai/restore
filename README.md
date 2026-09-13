# restore — one command for a new Mac

Public on purpose: this repo holds **no secret**, only the order of operations. Everything
private arrives after `gcloud auth login` (age identity + vault from GCP Secret Manager),
then from the age vault, then from the private repos.

```sh
curl -fsSLo bootstrap.sh https://raw.githubusercontent.com/vuihoc-ai/restore/main/bootstrap.sh
shasum -a 256 bootstrap.sh   # must print the SHA256 below
bash bootstrap.sh
```

| touch | when | why |
|---|---|---|
| 1 | first minute | `sudo` for Xcode CLT + Homebrew, then `sudo -k` |
| 2 | ~3 min | `gcloud auth login` in the browser (Google) |
| 3 | only if a Google profile was rejected | `taka-profiles.sh --login <p>` |

Everything else is `~/.claude/restore/restore-all.sh` (claude-config): DR bundle, repos,
memory, brew bundle, venvs, browser profiles, launchd, Claude Code token, `verify.sh`.
Re-run `restore-all.sh` any time; `--from P4` redoes from a phase.

## SHA256

`bootstrap.sh` = `7a883a73d662aee4ebaa276d79a74752211c9501e22d534a5ba1502b5e04936e`

Update this line whenever bootstrap.sh changes (`make sha`).
