# GitHub signed-commit ruleset on openeyes/openeyes (2026-08)

Upstream turned on a repository ruleset requiring verified signatures around
2026-08 - commits that pushed fine in July now bounce with GH013. The push is
declined wholesale, so the offending commit never lands on the remote and
amending it locally is safe. First seen on `fix/OE-18227`:

```
remote: error: GH013: Repository rule violations found for refs/heads/fix/OE-18227.
remote: - Commits must have verified signatures.
remote:   Found 1 violation:
remote:   403a34ba3ab7ae511a3162759ab4842a69201d96
 ! [remote rejected]       fix/OE-18227 -> fix/OE-18227 (push declined due to repository rule violations)
```

- Diagnose with `git log --show-signature -1` - nothing between the commit line
  and the author = unsigned.
- One-time setup in Git Bash, reusing the SSH key the push already
  authenticates with: `git config --global gpg.format ssh` then
  `git config --global user.signingkey "$(ls ~/.ssh/id_*.pub | head -1)"` then
  `git config --global commit.gpgsign true`. With more than one keypair in
  ~/.ssh, set the path explicitly to the key GitHub authenticates with.
- GitHub must hold the key as a *signing* key: Settings > SSH and GPG keys >
  New SSH key > key type "Signing Key". The same public key registered for
  auth does not count - add it a second time with the signing type, or the
  commit signs fine and still shows Unverified.
- Re-sign the rejected tip in place: `git commit --amend --no-edit -S`, then
  `git push`.
- A run of unsigned local commits: with `commit.gpgsign true` set,
  `git rebase -f origin/develop` rewrites and signs the lot.
- `git log --show-signature` locally reports "No signature" for SSH-signed
  commits unless `gpg.ssh.allowedSignersFile` points at a file of
  `<email> <pubkey>` lines - GitHub's Verified badge does not need that, so
  don't chase it.
