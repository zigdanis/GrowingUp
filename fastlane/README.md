# GrowingUp release lanes

Run releases through the manually dispatched, master-only GitHub Actions
TestFlight workflow. No local Mac or Apple account password is required.

See [TestFlight from Linux / T3 Code](../docs/testflight.md) for secure one-time
setup, preflight, deployment, status and retry commands.

- `ios release_preflight`: check account, tester access and app/widget signing.
- `ios app_store`: archive/upload a new release, or resume its exact build.
- `ios release_status`: read processing and distribution without uploading.

The first delivery is complete only after Danis confirms receipt on his phone.
