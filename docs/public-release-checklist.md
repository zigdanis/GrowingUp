# Public Release Checklist

Complete these repository-owner actions before changing the repository
visibility to public:

- [ ] Revoke or rotate every credential that has ever been committed, even if
  it is no longer used.
- [ ] Confirm that the repository owner accepts public access to historical
  source files and images in every retained branch and tag.
- [ ] Audit pull requests, issues, Actions logs, artifacts, releases, branches,
  and tags for sensitive data.
- [ ] Run `scripts/check-secrets.sh` against the exact commit to publish.
- [ ] Build and test the exact commit to publish.
- [ ] Enable secret scanning, push protection, Dependabot alerts, private
  vulnerability reporting, and branch protection after publication.

Keeping the existing repository and its history is acceptable once every
historically committed credential has been revoked or rotated. Deleting a
secret from the current source tree does not revoke it.
