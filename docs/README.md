# BTChess Documentation

BTChess is a mobile chess app for Android and iOS. It supports same-device play, offline Bluetooth Low Energy multiplayer, local game saving, game history, and board customization.

This page helps you choose the right path based on how you want to contribute:

- [Report a bug](#report-a-bug).
- [Suggest a new feature or improvement](#suggest-a-feature).
- [Contribute code to the project](#contribute-code).

## Report a Bug

If something does not work as expected, please open a [GitHub Issue](https://github.com/KaitoJD/btchess/issues/new?template=bug_report.yml). Bug reports are useful even if you are not sure what caused the problem.

When reporting a bug, include as much of this information as you can:

- What you expected to happen.
- What actually happened.
- Steps to reproduce the problem, if possible.
- Your device model, Android/iOS version, and app version.
- Screenshots, screen recordings, or error messages if they help explain the issue.

Bug reports are especially helpful for:

- Bluetooth connection or pairing problems.
- Crashes, freezes, or broken screens.
- Incorrect chess behavior.
- Save, resume, or game history problems.
- Device-specific installation or runtime issues.

## Suggest a Feature

If you have an idea for a new feature, setting, UI improvement, or quality-of-life change, open a [GitHub Issue](https://github.com/KaitoJD/btchess/issues/new?template=feature_request.yml) and describe the idea.

A good feature request usually explains:

- The problem or friction you noticed.
- The change you would like to see.
- Why it would make BTChess better.
- Any examples, screenshots, or references that help explain the idea.

For broader questions, early ideas, or open-ended discussion, use [GitHub Discussions](https://github.com/KaitoJD/btchess/discussions).

## Contribute Code

If you want to contribute code, start with the project workflow and then read the technical documents that match the area you want to work on.

Start here:

- [Contributing Guide](/CONTRIBUTING.md) - how to prepare changes and open pull requests.
- [Development Setup](/docs/dev_setup.md) - local tools, dependencies, and common commands.
- [Architecture](/docs/architecture.md) - app layers, state management, routing, persistence, and feature boundaries.

Area-specific references:

- [BLE Protocol](/docs/binary_protocol.md) - Bluetooth message format, move sync, and protocol rules.
- [Troubleshooting](/docs/troubleshooting.md) - common development, build, test, and Bluetooth problems.
- [iOS Setup (Optional)](/docs/ios_setup.md) - optional iOS development setup notes.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).

See the [LICENSE](/LICENSE) file for details.
