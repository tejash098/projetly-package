# Projetly 2GP Package

A Salesforce 2GP managed package that automatically delivers real-time webhook events to your external platform whenever Account, Contact, or Opportunity records are created, updated, or deleted — with zero configuration required after installation.

![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Version](https://img.shields.io/badge/version-0.1.0-orange)
![API Version](https://img.shields.io/badge/Salesforce%20API-v66.0-blue)
![Coverage](https://img.shields.io/badge/test%20coverage-85%25%2B-brightgreen)
![AppExchange](https://img.shields.io/badge/AppExchange-ready-blue)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Payload Format](#payload-format)
- [Security Headers](#security-headers)
- [Supported Objects and Events](#supported-objects-and-events)
- [Components](#components)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Testing](#testing)
- [Governor Limits and Bulkification](#governor-limits-and-bulkification)
- [AppExchange Compliance](#appexchange-compliance)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

---

## Overview

Projetly bridges Salesforce CRM data with external platforms by firing signed HTTP webhook events the moment records change. It is built for production workloads, handles bulk operations without extra callouts, retries on transient failures, and requires no manual admin setup after package installation.

**Problem it solves:** Teams using external project management tools, analytics platforms, or custom backends alongside Salesforce have no native way to receive real-time CRM record change events. Projetly fills that gap with a drop-in managed package.

---

## Architecture

```
Record Change (DML)
        |
        v
   Apex Trigger
  (AccountTrigger / ContactTrigger /
   OpportunityTrigger / OpportunityContactRoleTrigger)
        |
        | Collects all record IDs in the transaction
        v
  ProjetlyQueueable
  (Queueable + Database.AllowsCallouts)
        |
        | Async execution — safe for HTTP callouts
        v
  ProjetlyWebhookService.sendBatch()
        |
        | Builds JSON payload + generates HMAC-SHA256 signature
        v
  HTTP POST via Named Credential (Projetly_Webhook)
  Headers: x-sf-request-id, x-sf-timestamp, x-sf-signature
        |
        | On failure (non-2xx or exception)
        v
  Retry up to 3 attempts (re-enqueue with incremented retryCount)
```

Each trigger collects all record IDs in the current transaction into a single `Set<Id>` before enqueuing one `ProjetlyQueueable` job. This guarantees a single HTTP callout per object per transaction regardless of how many records changed.

---

## Payload Format

Every webhook POST sends the following JSON body:

```json
{
  "org_id": "00D000000000001AAA",
  "user_id": "005000000000001AAA",
  "trigger_type": "create",
  "record_ids": ["001000000000001AAA", "001000000000002AAA"],
  "object": "account",
  "timestamp": "1713870000000"
}
```

| Field | Type | Description |
|---|---|---|
| `org_id` | String | Salesforce Organization ID |
| `user_id` | String | ID of the user who performed the DML operation |
| `trigger_type` | String | `create`, `update`, or `delete` |
| `record_ids` | Array | All record IDs affected in the transaction |
| `object` | String | `account`, `contact`, or `opportunity` |
| `timestamp` | String | Epoch milliseconds when the event was generated |

The endpoint is configured in the `Projetly_Webhook` Named Credential. The base URL is updated per deployment environment.

---

## Security Headers

Every outbound webhook request includes three custom headers for authenticity verification:

| Header | Format | Description |
|---|---|---|
| `x-sf-request-id` | 16-character alphanumeric string | Unique ID for this request (timestamp prefix + random suffix) |
| `x-sf-timestamp` | Epoch milliseconds (string) | Time the request was generated; matches `timestamp` in the payload body |
| `x-sf-signature` | `sha256=<64-char-hex>` | HMAC-SHA256 signature for payload verification |

### Verifying the Signature

The signature is computed as:

```
rawPayload  = timestamp + "." + requestBody
signature   = "sha256=" + HMAC-SHA256(rawPayload, webhookSecret)
```

Where `webhookSecret` is the value stored in the `Projetly_Config__mdt` Custom Metadata record. On the receiving end:

1. Read `x-sf-timestamp` from the request headers.
2. Concatenate `timestamp + "." + rawBody` using the exact body bytes received.
3. Compute HMAC-SHA256 using your shared secret.
4. Compare the result (prefixed with `sha256=`) to the `x-sf-signature` header value.

If the values match, the request is authentic and has not been tampered with.

---

## Supported Objects and Events

| Object | after insert | after update | after delete | object value in payload |
|---|---|---|---|---|
| Account | create | update | delete | `account` |
| Contact | create | update | delete | `contact` |
| Opportunity | create | update | delete | `opportunity` |
| OpportunityContactRole | create | update | delete | `contact` (fires Contact IDs) |

`OpportunityContactRole` events are treated as Contact relationship changes: the Contact IDs from the role records are sent with `object = contact`, keeping the consumer side simple.

---

## Components

### Apex Triggers

| File | Object | Events |
|---|---|---|
| `AccountTrigger.trigger` | Account | after insert, after update, after delete |
| `ContactTrigger.trigger` | Contact | after insert, after update, after delete |
| `OpportunityTrigger.trigger` | Opportunity | after insert, after update, after delete |
| `OpportunityContactRoleTrigger.trigger` | OpportunityContactRole | after insert, after update, after delete |

### Apex Classes

| Class | Purpose |
|---|---|
| `ProjetlyWebhookService` | Builds the JSON payload, generates HMAC-SHA256 signature, and executes the HTTP POST |
| `ProjetlyQueueable` | Async wrapper with retry logic (up to 3 attempts) |
| `ProjetlyPostInstallHandler` | Post-install script: verifies Named Credential and assigns `Projetly_User` permission set to the installer |
| `ProjetlyHttpMock` | `HttpCalloutMock` implementation used in tests; validates all three security headers |
| `ProjetlyTest` | Comprehensive test class (85%+ coverage) |

### Metadata

| Component | Type | Purpose |
|---|---|---|
| `Projetly_Webhook` | Named Credential | Stores the webhook base URL, enables callout authorization |
| `Projetly_Config__mdt` | Custom Metadata Type | Stores the HMAC-SHA256 webhook secret (protected field; subscriber orgs cannot read) |
| `Projetly_Config.Default` | Custom Metadata Record | Default config record; set `Webhook_Secret__c` before go-live |
| `Projetly_User` | Permission Set | Base permission set for Projetly package users; auto-assigned on install |

---

## Installation

### Prerequisites

- Salesforce CLI (`sf`) installed and authenticated
- Target org must have outbound HTTP callouts enabled
- API version 66.0 or higher

### Install via Package Version ID

```bash
sf package install \
  --package 04tgK000000CPaXQAW \
  --target-org <your-org-alias> \
  --wait 10
```

Use the table below to install a specific build:

| Build | Package Version ID |
|---|---|
| 0.1.0-1 | `04tgK000000C8g9QAC` |
| 0.1.0-2 | `04tgK000000C8zVQAS` |
| 0.1.0-3 | `04tgK000000C95xQAC` |
| 0.1.0-4 | `04tgK000000C9HFQA0` |
| 0.1.0-5 | `04tgK000000C9NhQAK` |
| 0.1.0-6 | `04tgK000000C9YzQAK` |
| 0.1.0-7 | `04tgK000000C9ltQAC` |
| 0.1.0-8 | `04tgK000000C9nVQAS` |
| 0.1.0-9 | `04tgK000000C9p7QAC` |
| 0.1.0-10 | `04tgK000000C9txQAC` |
| 0.1.0-11 | `04tgK000000CA0PQAW` |
| 0.1.0-12 | `04tgK000000CBqvQAG` |
| 0.1.0-13 | `04tgK000000CC5RQAW` |
| 0.1.0-14 | `04tgK000000CLqHQAW` |
| 0.1.0-15 | `04tgK000000CMCrQAO` |
| 0.1.0-16 | `04tgK000000CMHhQAO` |
| 0.1.0-17 | `04tgK000000CMMXQA4` |
| 0.1.0-18 (latest) | `04tgK000000CPaXQAW` |

### Install for Development (Source Deploy)

```bash
# Clone the repository
git clone <repository-url>
cd projetly-app

# Authenticate to your scratch org or sandbox
sf org login web --alias my-org

# Deploy source
sf project deploy start --target-org my-org

# Run tests to verify
sf apex run test --target-org my-org --synchronous
```

### Create a Scratch Org (optional)

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias projetly-scratch \
  --duration-days 7

sf project deploy start --target-org projetly-scratch
```

---

## Usage

After installation, the package works automatically. No admin configuration is required beyond setting the webhook secret (see [Configuration](#configuration)).

**Verify triggers are active:**

```bash
sf data query \
  --query "SELECT Id, Name, Status FROM ApexTrigger WHERE NamespacePrefix = 'Projetly'" \
  --target-org my-org
```

**Verify Named Credential is deployed:**

```bash
sf data query \
  --query "SELECT Id, DeveloperName, Endpoint FROM NamedCredential WHERE DeveloperName = 'Projetly_Webhook'" \
  --target-org my-org
```

**Simulate a trigger event manually (from Developer Console or VS Code):**

```apex
// Anonymous Apex — fires the webhook for a specific record
Set<Id> ids = new Set<Id>{ '001000000000001AAA' };
System.enqueueJob(new Projetly.ProjetlyQueueable(ids, 'update', 'account', 0));
```

**Sample webhook payload received by your server:**

```json
{
  "org_id": "00D5g000000ABCDEAA",
  "user_id": "0055g000000UVWXYAA",
  "trigger_type": "delete",
  "record_ids": [
    "0015g000000LMNOPAA",
    "0015g000000LMNOPAB",
    "0015g000000LMNOPC"
  ],
  "object": "account",
  "timestamp": "1713870000000"
}
```

**Sample request headers:**

```
x-sf-request-id: a1b2c3d4e5f67890
x-sf-timestamp:  1713870000000
x-sf-signature:  sha256=3d9b4c1a...
```

---

## Configuration

### Updating the Webhook Endpoint

The destination URL is managed through the `Projetly_Webhook` Named Credential. To point it at a different server:

1. Navigate to Setup > Named Credentials
2. Open `Projetly Webhook`
3. Update the URL field to your endpoint
4. Save

Alternatively, update the Named Credential metadata before deployment:

```xml
<!-- force-app/main/default/namedCredentials/Projetly_Webhook.namedCredential-meta.xml -->
<NamedCredential>
    <label>Projetly Webhook</label>
    <endpoint>https://your-production-server.com/api/salesforce</endpoint>
    <principalType>Anonymous</principalType>
    <protocol>NoAuthentication</protocol>
</NamedCredential>
```

### Setting the Webhook Secret

The HMAC-SHA256 signing key is stored in the `Projetly_Config__mdt` Custom Metadata record (`Projetly_Config.Default`). The field `Webhook_Secret__c` ships with a placeholder value and **must be updated before go-live**.

Update the metadata record before deployment:

```xml
<!-- force-app/main/default/customMetadata/Projetly_Config.Default.md-meta.xml -->
<CustomMetadata>
    <label>Default</label>
    <values>
        <field>Webhook_Secret__c</field>
        <value xsi:type="xsd:string">your-strong-secret-here</value>
    </values>
</CustomMetadata>
```

Or update it via Setup > Custom Metadata Types > Projetly Config > Manage Records > Default.

> **Note:** `Webhook_Secret__c` is a protected field — subscriber orgs cannot read or export it, which keeps the signing secret secure in managed package deployments.

### Retry Behavior

Retries are handled inside `ProjetlyQueueable`. The defaults are:

| Setting | Value |
|---|---|
| Max retry attempts | 3 |
| Retry trigger | HTTP status outside 200-299, or any exception |
| Retry mechanism | Re-enqueue with `retryCount + 1` |
| Stop condition | `retryCount >= 3` |

No code changes are needed to enable retries — they are always on.

---

## Testing

Run the full test suite:

```bash
sf apex run test \
  --target-org my-org \
  --test-level RunLocalTests \
  --synchronous \
  --result-format human
```

Run only Projetly tests:

```bash
sf apex run test \
  --target-org my-org \
  --class-names ProjetlyTest \
  --synchronous \
  --result-format human
```

### Test Coverage Summary

| Scenario | Test Method |
|---|---|
| Account insert / update / delete | `testAccountTrigger` |
| Contact insert / update / delete | `testContactTrigger` |
| Opportunity insert / update / delete | `testOpportunityFlow` |
| OCR insert / update / delete (Contact IDs) | `testOCRTrigger` |
| 200-record bulk insert | `testBulkOpportunities` |
| 50-record bulk delete in one payload | `testBulkDelete` |
| Successful callout | `testDirectSendBatch_success` |
| Failed callout (503 response) | `testDirectSendBatch_failure` |
| Empty record ID set (no-op) | `testDirectSendBatch_emptyIds` |
| Null record IDs (no-op) | `testDirectSendBatch_nullIds` |
| Retry on failure | `testRetryOnFailure` |
| Retry chain stops at attempt 3 | `testQueueableRetryChain` |
| Null IDs in queueable | `testQueueableNullIds` |
| Empty IDs in queueable | `testQueueableEmptyIds` |
| HMAC signature deterministic output | `testSignatureGeneration` |
| Different inputs produce different signatures | `testSignatureGeneration` |
| Post-install: new install | `testPostInstall_newInstall` |
| Post-install: upgrade path | `testPostInstall_upgrade` |
| Post-install: duplicate PS prevention | `testPostInstall_duplicatePS` |

`ProjetlyHttpMock` validates all three security headers (`x-sf-request-id`, `x-sf-timestamp`, `x-sf-signature`) on every test callout.

---

## Governor Limits and Bulkification

| Concern | How it is handled |
|---|---|
| Multiple records in one DML | All IDs collected into `Set<Id>` before a single `enqueueJob` call |
| Callout in trigger context | Callout deferred to `ProjetlyQueueable` (async, `Database.AllowsCallouts`) |
| SOQL inside loops | No SOQL queries exist anywhere in trigger or handler code |
| DML inside loops | No DML in any trigger or handler |
| Queueable depth | One job per trigger per transaction; retries chain but cap at 3 |
| Heap and CPU | `Set<Id>` deduplication keeps payloads compact; no unbounded collections |

---

## AppExchange Compliance

| Requirement | Status |
|---|---|
| No hardcoded sensitive credentials | Named Credential handles endpoint; HMAC secret stored in protected Custom Metadata field |
| HTTPS-only callouts | Named Credential endpoint enforces HTTPS |
| No prohibited Apex patterns | No dynamic SOQL, no unrestricted callouts |
| CRUD/FLS | Package reads no custom object data; standard object triggers are read-only |
| Namespace declared | `Projetly` namespace applied to all components |
| No test code in production classes | Test mock and test class are `@isTest` isolated |
| Minimum 75% code coverage | Current coverage exceeds 85% |
| No debug-only production code | All `System.debug` calls use appropriate logging levels (WARN / ERROR) |
| Bulk-safe triggers | Verified against 200-record insert and 50-record delete in tests |
| Payload signing | All outbound requests signed with HMAC-SHA256; secret stored in protected field |

---

## Roadmap

- [ ] Custom Metadata Type for per-object webhook URL overrides
- [ ] Event filtering (e.g., only fire on specific field changes)
- [ ] Dead-letter logging via custom object for failed webhook attempts after 3 retries
- [ ] Flow-triggered webhook support (without Apex triggers)
- [ ] Support for additional standard objects (Lead, Case, Task)
- [ ] Configurable retry cap via Custom Metadata

---

## Contributing

1. Fork the repository and create a feature branch from `main`.
2. Create a scratch org and deploy the source:

   ```bash
   sf org create scratch --definition-file config/project-scratch-def.json --alias dev-scratch
   sf project deploy start --target-org dev-scratch
   ```

3. Make your changes. Ensure all tests pass and coverage stays at or above 85%:

   ```bash
   sf apex run test --target-org dev-scratch --synchronous
   ```

4. Run the Salesforce Scanner for security and PMD compliance before opening a pull request:

   ```bash
   sf scanner run --target force-app --format table
   ```

5. Open a pull request against `main` with a clear description of what changed and why.

**Code standards:**
- No SOQL or DML inside loops
- All callouts must go through Named Credentials
- Every new code path must have a corresponding `@isTest` method
- Follow the handler class pattern — triggers must stay minimal
- All outbound HTTP requests must include the three security headers