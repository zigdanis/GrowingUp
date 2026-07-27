# Public Release Checklist

Complete these repository-owner actions before changing the repository
visibility to public:

- [ ] Revoke or rotate every credential that has ever been committed, even if
  it is no longer used.
- [ ] Publish from a clean snapshot without the existing Git history, or scrub
  every branch and tag containing credentials or personal images.
- [ ] Audit pull requests, issues, Actions logs, artifacts, releases, branches,
  and tags for sensitive data.
- [ ] Run `scripts/check-secrets.sh` against the exact commit to publish.
- [ ] Build and test the exact commit to publish.
- [ ] Enable secret scanning, push protection, Dependabot alerts, private
  vulnerability reporting, and branch protection after publication.

The safest release path is a new public repository created from a clean
snapshot of the reviewed source tree. Keep the current private repository as
an archive rather than exposing its historical objects and metadata.
