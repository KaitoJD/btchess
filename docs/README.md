_This folder is the technical entry point for contributors. Use it to understand architecture boundaries, local development workflow, BLE protocol constraints, and common failure modes._

## Start Here

If you are new to the project, read in this order:

1. [Development Setup](./dev_setup.md): toolchain, run/build commands, emulator and BLE testing constraints.
2. [Architecture](./architecture.md): layer boundaries, dependency rules, and state-management flow.
3. [Binary Protocol](./binary_protocol.md): BLE message format, reliability rules, and compatibility constraints.
4. [Troubleshooting](./troubleshooting.md): known issues and fixes for BLE, persistence, and builds.
## Contribution Workflow

1. Pull latest `master` and install dependencies (`flutter pub get`).
2. Make changes in the correct layer (see Codebase Map below).
3. If changing Hive models/adapters, regenerate generated files with build_runner.
4. Run tests locally (`flutter test`) and verify affected app flows.
5. For BLE-related changes, validate on two physical devices. Emulators/simulators are not sufficient for BLE behavior.
6. Update documentation when behavior, protocol expectations, or developer workflow changes.

## Codebase Map (Where Changes Belong)

This project follows strict layer boundaries:

- `core/`: shared constants, utilities, error types, protocol constants, and low-level helpers.
- `domain/`: chess business logic, models, enums, and core services.
- `application/`: Riverpod controllers/providers and application orchestration.
- `presentation/`: Flutter UI, routes, and widgets.
- `infrastructure/`: BLE transport, persistence, preferences, and other external integrations.

Read [Architecture](./architecture.md) before introducing new dependencies across layers.

## What Not To Change Lightly

- BLE protocol wire format and message semantics in [Binary Protocol](./binary_protocol.md).
- Layer dependency rules documented in [Architecture](./architecture.md).
- Reliability assumptions (ACK timeouts/retries/rate limits) that affect interoperability.

If these must change, update implementation and documentation together, and validate compatibility impacts.

## Documentation Map

- [dev_setup.md](./dev_setup.md): environment setup, build/run commands, BLE test procedure, and code generation.
- [architecture.md](./architecture.md): technical architecture, provider/controller responsibilities, and data flow.
- [binary_protocol.md](./binary_protocol.md): protocol specification, message contracts, and reliability behavior.
- [troubleshooting.md](./troubleshooting.md): diagnosis and recovery steps for common developer issues.
