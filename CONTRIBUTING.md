# Contributing to Makhtoot

Makhtoot welcomes Arabic typography reports, documentation corrections, small code fixes, and contributions of fonts or artwork with documented redistribution rights. The maintainer, **@binjamshid**, reviews scope and decides what enters the official project. Arabic and English issue reports are welcome.

## Your first pull request

1. Check the platform status in the [README](README.md) and look for an existing issue. For a small correction, you can open a pull request directly. For a new feature, public format change, dependency, or change in shaping behavior, describe the proposal and expected result in an issue first.
2. For an owner-authorized public source release, fork the repository, clone your fork and create a topic branch. If you have access to a private checkout, keep your work within that authorized private repository network. Private access carries no permission to publish it.
3. Make one reviewable change. Use the [build guide](docs/BUILD.md) for a focused check appropriate to the touched platform. For layout or rendering, attach a small, shareable before/after example and name the font, device or simulator, OS and app revision. For a documentation edit, open the result and follow the changed links.
4. Push the topic branch to your fork. Open a pull request against the upstream repository's `main`. Describe the problem, the change, what you checked and what still needs a device or account. Preserve copyright and license notices and use your own Git identity.
5. Respond to review on the same branch. The maintainer resolves the scope and merges the PR when ready. Changes to `main` go through a pull request and review conversations must be resolved; force pushes and deletion of `main` are blocked.

For example, after cloning your fork and entering its directory:

```sh
git switch -c fix/arabic-mark-placement
# Edit, run the relevant check, then commit your change.
git push -u origin HEAD
```

## What rights are you contributing?

Submit code you own or have permission to contribute. By submitting your own changes to the covered software for inclusion, you offer those changes under the same [Binjamshid Public Fork License, Version 1.0](LICENSE). Retain separate upstream licenses for third-party material. For a font, ornament or sample design, provide the upstream source, author or foundry, exact version, license text, and the rights that permit everyone to receive and redistribute it. Include permission for any marks, images or text in a screenshot. [Asset rights](docs/asset-rights.md)

**Publishing a fork and contributing upstream are separate choices.** For a public release covered by this license, publish corresponding source for each modified version under the exact license within 30 calendar days of the change, or before first distribution or use by others as a service, whichever comes first. This includes private, uncommitted and abandoned edits. Each version must remain recoverable, freely downloadable without registration while distributed or offered as a service and for at least twelve months after first publication. Give recipients and service users a link to the corresponding source. An upstream PR is optional. A squash that discards intermediate versions from your only public copy can defeat recoverability. Sections 3–5 give the commercial restrictions, security exception, source requirements and notice obligations. [Full license](LICENSE)

## Reporting a problem

- **A glyph or mark looks wrong.** Include the exact selectable Arabic text and a minimal example in a shareable font. Describe where it first goes wrong: typing, arranging, reopening or exporting. [Typography testing guide](docs/typography-testing.md)
- **A build fails.** Give the revision, OS, toolchain, failing command and relevant error lines. Remove private paths, project contents, credentials and account identifiers.
- **Security or private conduct issue.** Use the private contact in the relevant policy. [Security](SECURITY.md) · [Code of conduct](CODE_OF_CONDUCT.md)
