# Contributing to Scribbler

Thanks for your interest in improving Scribbler.

## Bugs and feature requests

Before opening a GitHub Issue, search existing issues to avoid duplicates. For bugs, include:

- Scribbler version and macOS version
- Steps to reproduce
- Expected and actual results
- Relevant error messages or screenshots, with personal information removed

**Never upload real documents, recovery snapshots, credentials, or private information** to an issue.

## Pull requests

1. Open an issue first for substantial changes, so the approach can be discussed.
2. Fork the repository and create a focused branch.
3. Keep changes small and describe the motivation and behavior.
4. Run the available recovery regression tests and the macOS build.
5. Include testing steps and, where possible, automated regression coverage.
6. Submit a pull request against `main`. Maintainers review before merging.

## Build and test

Requires a Mac with Xcode and the macOS SDK. Open `Scribbler.xcodeproj` and select the `Scribbler` scheme, or run:

```sh
xcodebuild -project Scribbler.xcodeproj -scheme Scribbler \
  -configuration Debug -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build

swiftc NativeEditor/RecoveryVault.swift Tests/RecoveryVaultTests.swift \
  -o /tmp/scribbler-recovery-tests
/tmp/scribbler-recovery-tests
```

GitHub Actions also runs these checks for pull requests.

## Security reports

Please **do not disclose exploitable vulnerabilities, secrets, or sensitive user data in public issues**. Contact the repository maintainer privately through an appropriate GitHub contact channel before publishing details.

## License

By contributing, you agree that your contributions are provided under the project's MIT License.
