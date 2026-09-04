# CuttleOS documentation

## Architecture

- [System architecture](system-architecture.md) — cross-repository system authority
- [Control architecture](control-architecture.md) — command, safety, and actuator-control boundaries
- [Hardware interface](hardware-interface.md) — software-to-hardware boundary, node identity, and RS-485 principles
- [Adeept ADM133 Control driver](adeept-adm133-control-driver.md) — shared ADM133 adapter contract, resource reservations, and validation plan
- [NATS contract](nats-contract.md) — application messaging and interface principles
- [Test provenance](test-provenance.md) — test-run identity, provenance, lifecycle markers, capability, and validation evidence

## Engineering and development

- [Development](development.md)
- [Historical ROV notes](historical-rov-notes.md)
- [Deployment](deployment.md)
- [Platform support](platform-support.md)
- [Engineering principles](engineering-principles.md)
- [Testing](testing.md)
- [CI/CD Pipeline](ci-cd.md)
- [Documentation currency policy](documentation-policy.md)
- [Current status](status.md)
- [Repository context](../MASTER_CONTEXT.md)
- [Project roadmap](../ROADMAP.md)

Configuration examples are in `../configs/`. Copy `users.example.json` to `users.json` and set credentials before enabling authenticated use.
