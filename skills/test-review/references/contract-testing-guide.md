# Contract Testing Guide

Reference for AI reviewers. Read this when the codebase has service-to-service calls.

---

## When Required

Apply contract testing scrutiny when:
- Service-to-service boundary crossing **team ownership** with **independent deployments**
- Consumer and provider can deploy on different schedules

Skip contract testing scrutiny when:
- Monorepos with coordinated deployments (all services release together)
- Stable versioned SDKs with explicit semver guarantees (the version IS the contract)

---

## Consumer-Driven vs Provider-Driven

**Consumer-Driven (Pact)**
- Consumer team defines expected interactions → provider verifies against them
- Best when consumer team moves faster than provider or when multiple consumers exist
- `can-i-deploy` gate in CI enforces compatibility before any deployment

**Provider-Driven (Spring Cloud Contract, Specmatic)**
- Provider publishes contract → consumers generate stubs from it
- Best for spec-first shops or OpenAPI-first API design
- Specmatic has built-in backward compatibility checking

**Bi-Directional (PactFlow BDCT)**
- Static cross-contract comparison using existing mocks or OpenAPI specs
- More than 50% less effort than full CDCT
- Best for teams already maintaining OpenAPI specs + existing mock libraries

---

## Tools Reference

| Tool | Type | Best For |
|---|---|---|
| Pact | Consumer-driven | Language-neutral, most mature; gRPC via pact-protobuf-plugin; `can-i-deploy` CI gate |
| Spring Cloud Contract | Provider-driven | JVM shops; central Git contract repo |
| Specmatic | Provider-driven | OpenAPI-as-contract; spec-first shops; backward compat built-in |
| Dredd | One-directional | Simplest entry point; validates provider against OpenAPI only |
| Microcks + Karate | Event-driven | AsyncAPI/Kafka/AMQP contract validation |
| Schemathesis | NOT contract testing | Property-based API fuzzing (complementary, finds ~4.5x more defects than manual) |

---

## Reviewer Red Flags

Flag these as findings during landscape mapping and test review:

- **HTTP mocks with no contract file** — `nock`, `WireMock`, `requests_mock`, `responses` used to stub downstream services but no `.pact` file, Specmatic spec, or equivalent contract artifact exists. Severity: **HIGH**.
- **Integration tests hitting real downstream services** — fragile, slow, creates tight deployment coupling. Recommend replacing with contract tests + consumer stubs.
- **No `can-i-deploy` or equivalent CI gate** — contracts exist but nothing blocks a breaking deployment. Severity: **HIGH**.
- **Empty `@State` / `stateHandlers`** — provider tests skip state setup, making provider verification meaningless.
- **Exact-match assertions on dynamic values** — contracts asserting on timestamps, UUIDs, auto-incremented IDs will produce false failures. Use type matchers or regex matchers.
- **GraphQL endpoints with no schema-based contract validation** — REST gets OpenAPI scrutiny; GraphQL schema drift is equally dangerous.

---

## Protocol-Specific Patterns

**GraphQL**
- The schema IS the contract — check for schema registry or schema-as-contract enforcement
- Pact supports GraphQL interaction definitions; look for these in consumer tests
- Schema breaking change detection (removal of fields, type changes) should be in CI

**gRPC**
- Protobuf definition is the contract for structure, but does not capture which fields consumers actually use
- Still need consumer-driven verification to catch "provider removed optional field consumers relied on" scenarios
- pact-protobuf-plugin enables Pact-style consumer-driven tests over gRPC

**Event-Driven (Kafka, AMQP, SNS/SQS)**
- AsyncAPI spec + Microcks is the reference pattern for event contract testing
- Look for schema registry usage (Confluent Schema Registry, AWS Glue Schema Registry)
- Absence of schema registry on a Kafka-heavy codebase = flag as gap

---

## Reviewer Actions (Ordered)

1. **Landscape mapping** — detect all service-to-service HTTP/gRPC/message calls. Note team ownership boundaries.
2. **Check for contract artifacts** — `.pact` files, `contractTest` directories, Specmatic specs, Spring Cloud Contract stubs.
3. **Check mocking libraries** — if mocks exist without corresponding contract files, flag HIGH.
4. **Check integration test scope** — if integration tests spin up real downstream containers/services, recommend contract test replacement.
5. **Check CI pipeline** — look for `can-i-deploy`, `specmatic test`, or equivalent gate blocking deployment on contract failure.
6. **Event-driven check** — if Kafka/AMQP present, look for AsyncAPI specs and schema registry usage.
7. **Protocol-specific checks** — apply GraphQL and gRPC patterns above if those protocols are in scope.
