# Contributing to Baby App Audit

Thank you for your interest. This project audits baby tracking apps for privacy leaks.

## How to contribute

1. **Open an issue** before starting work. Describe the bug or feature.
2. **Fork the repository** and create a branch.
3. **Follow the existing style.** Shell scripts use `bash` with `set -euo pipefail`. Markdown files must pass the checks in `AGENTS.md`.
4. **Run tests before submitting.** See `AGENTS.md` for the test commands.
5. **Submit a pull request** with a clear description.

## What I am looking for

- New app candidates to test (see `localonly/candidates.md`)
- Bug fixes in the test harness
- Improvements to the dark pattern detection heuristics
- Documentation corrections

## What I am not looking for

- Complete rewrites of the harness
- New dependencies without justification
- Style-only changes

## Code of conduct

Be respectful. Assume good intent. Focus on the evidence.

## License

By contributing, you agree that your contributions will be licensed under the GNU General Public License v3.0.
