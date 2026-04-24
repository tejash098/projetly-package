# Projetly 2GP Package

A Salesforce 2GP managed package that automatically delivers real-time webhook events to your external platform whenever Account, Contact, or Opportunity records are created, updated, or deleted — with zero configuration required after installation.

![Build](https://img.shields.io/badge/build-passing-red)
![Version](https://img.shields.io/badge/version-0.1.0-orange)
![API Version](https://img.shields.io/badge/Salesforce%20API-v66.0-blue)
![Coverage](https://img.shields.io/badge/test%20coverage-85%25%2B-y)

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup & Deployment](#setup--deployment)
- [Configuration](#configuration)
- [Testing](#testing)
- [Common Errors & How to Fix Them](#common-errors--how-to-fix-them)

---

## Prerequisites

- **Salesforce CLI (`sf`)** — v2 or later
- **Node.js** — v18 or later (required by Salesforce CLI)
- Target org must have outbound HTTP callouts enabled
- Salesforce API version 66.0 or higher

### Install Salesforce CLI

```bash
npm install --global @salesforce/cli
```

> Reference: [https://developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli)

### Install Node.js

> Reference: [https://nodejs.org/en/download](https://nodejs.org/en/download)

---

## Setup & Deployment

### 1. Clone the Repository

```bash
git clone <repository-url>
cd projetly-app
```

### 2. Authenticate to Dev Hub

```bash
sf org login web --alias dev-hub --set-default-dev-hub
```

### 3. Authenticate to Target Org

**Scratch org (recommended for development):**

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias <org-alias> \
  --set-default \
  --duration-days 7
```

**Sandbox or existing org:**

```bash
sf org login web --alias <org-alias>
```

### 4. Deploy Source

```bash
sf project deploy start --target-org <org-alias>
```

### 5. Run Tests After Deploy

```bash
sf apex run test \
  --target-org <org-alias> \
  --test-level RunLocalTests \
  --synchronous \
  --result-format human
```

### 6. Create a Package Version

```bash
sf package version create \
  --package <PackageName> \
  --definition-file config/project-scratch-def.json \
  --installation-key-bypass \
  --wait 20
```

### 7. Install the Package in a Target Org

Install the latest released version:

```bash
https://login.salesforce.com/packaging/installPackage.apexp?p0=<PackageVersionId>
```

Or install via CLI:

```bash
sf package install \
  --package 04tgK000000CRyvQAG \
  --target-org <your-org-alias> \
  --wait 10
```

All available versions:

| Build             | Package Version ID   |
| ----------------- | -------------------- |
| 0.1.0-1           | ``                   |
| 0.1.0-2           | ``                   |
| 0.1.0-3           | ``                   |
| 0.1.0-4           | ``                   |
| 0.1.0-19 (latest) | `04tgK000000CRyvQAG` |

### 8. Promote the Package Version (Production-Ready)

A package version must be promoted before it can be installed in production orgs or submitted to AppExchange.

```bash
sf package version promote \
  --package 04tgK000000CRyvQAG
```

Verify the promotion:

```bash
sf package version report \
  --package 04tgK000000CRyvQAG
```

---

## Configuration

Before going live, update the webhook endpoint, secret, and API key in the two metadata files below. Deploy the updated files to apply the changes.

### Webhook Endpoint

**File:** [force-app/main/default/namedCredentials/Projetly_Webhook.namedCredential-meta.xml](force-app/main/default/namedCredentials/Projetly_Webhook.namedCredential-meta.xml)

Replace the `<endpoint>` value with your server URL:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Projetly Webhook</label>
    <endpoint>your-domain-url</endpoint>
    <principalType>Anonymous</principalType>
    <protocol>NoAuthentication</protocol>
</NamedCredential>
```

Alternatively, update it via **Setup > Named Credentials > Projetly Webhook > Edit**.

### Webhook Secret and API Key

**File:** [force-app/main/default/customMetadata/Projetly_Config.Default.md-meta.xml](force-app/main/default/customMetadata/Projetly_Config.Default.md-meta.xml)

Replace both placeholder values before deploying:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Default</label>
    <protected>true</protected>
    <values>
        <field>Webhook_Secret__c</field>
        <value xsi:type="xsd:string">your-secret-here</value>
    </values>
    <values>
        <field>Function_Key__c</field>
        <value xsi:type="xsd:string">your-key-here</value>
    </values>
</CustomMetadata>
```

| Field               | Purpose                                                        |
| ------------------- | -------------------------------------------------------------- |
| `Webhook_Secret__c` | HMAC-SHA256 signing key for outbound request signatures        |
| `Function_Key__c`   | API key sent as the `x-functions-key` header for endpoint auth |

Alternatively, update via **Setup > Custom Metadata Types > Projetly Config > Manage Records > Default**.

> **Note:** Both fields are `protected` — subscriber orgs cannot read or export them, keeping secrets secure in managed package deployments.

After editing either file, redeploy to apply:

```bash
sf project deploy start --target-org <org-alias>
```

---

## Testing

### Run the Full Test Suite

```bash
sf apex run test \
  --target-org my-org \
  --test-level RunLocalTests \
  --synchronous \
  --result-format human
```

### Run Only Projetly Tests

```bash
sf apex run test \
  --target-org my-org \
  --class-names ProjetlyTest \
  --synchronous \
  --result-format human
```

### Verify Triggers Are Active

```bash
sf data query \
  --query "SELECT Id, Name, Status FROM ApexTrigger WHERE NamespacePrefix = 'Projetly'" \
  --target-org my-org
```

### Verify Named Credential Is Deployed

```bash
sf data query \
  --query "SELECT Id, DeveloperName, Endpoint FROM NamedCredential WHERE DeveloperName = 'Projetly_Webhook'" \
  --target-org my-org
```

### Fire a Webhook Manually (Anonymous Apex)

From Developer Console or VS Code, run:

```apex
Set<Id> ids = new Set<Id>{ '001000000000001AAA' };
System.enqueueJob(new Projetly.ProjetlyQueueable(ids, 'update', 'account', 0));
```

---

## Common Errors & How to Fix Them

This section covers the most frequent problems encountered when modifying or extending the package, and how to resolve each one.

---

### 1. Test Coverage Below 75%

**Error message:**

```
Average test coverage across all Apex Classes and Triggers is X%, at least 75% test coverage is required.
```

**Why it happens:** Salesforce requires a minimum of 75% code coverage across all Apex classes and triggers before a package version can be created. Adding new Apex logic without corresponding test methods will drop the average below the threshold.

**How to fix:**

1. Check current per-class coverage:
   ```bash
   sf apex run test \
     --target-org <org-alias> \
     --test-level RunLocalTests \
     --code-coverage \
     --result-format json \
     --output-dir coverage-report
   ```
2. Open the JSON report and find any class with `coveredPercent < 75`.
3. Add test methods to `ProjetlyTest.cls` (or the relevant test class) that exercise the uncovered lines — include both happy-path and error-path scenarios.
4. Use `Test.setMock(HttpCalloutMock.class, ...)` for any method that makes outbound HTTP calls, otherwise coverage is 0 for those lines during tests.
5. Re-run the version create command with `--code-coverage` to confirm before submitting.

> **Tip:** Lines inside `catch` blocks and one-liner guards are common coverage blind spots. Make at least one test deliberately trigger each exception path.

---

### 2. Object or Field Name Missing Namespace Prefix

**Error message (runtime or compile):**

```
Variable does not exist: MyObject__c
Invalid type: MyObject__c
SObject type 'MyObject__c' is not supported
```

**Why it happens:** In a 2GP managed package, every custom object, custom field, and custom metadata type is automatically prefixed with the package namespace (e.g., `Projetly__`) when deployed to a subscriber org. Apex code inside the package can reference its own objects without the prefix, but any **dynamic SOQL**, **Schema API string lookups**, or **cross-namespace references** must include it.

Common problem locations:

| Pattern | Without prefix (breaks) | With prefix (correct) |
|---|---|---|
| Dynamic SOQL string | `'SELECT Id FROM MyObject__c'` | `'SELECT Id FROM Projetly__MyObject__c'` |
| `Schema.getGlobalDescribe()` key | `'MyObject__c'` | `'Projetly__MyObject__c'` |
| `Type.forName()` | `'MyObject__c'` | `'Projetly__MyObject__c'` |
| Custom Metadata field access | `MyMeta__mdt.MyField__c` | `Projetly__MyMeta__mdt.Projetly__MyField__c` |

**How to fix:**

- For **static references** inside the package (class-to-class, trigger-to-class), the compiler resolves the namespace automatically — no change needed.
- For **dynamic strings** (SOQL built at runtime, `Schema.describeSObjects`, `Database.query`), always include the full `Namespace__ObjectName__c` form.
- Use a helper constant at the top of your utility class to avoid scattering the namespace string:
  ```apex
  private static final String NS = 'Projetly__';
  String query = 'SELECT Id FROM ' + NS + 'MyObject__c WHERE ' + NS + 'Status__c = \'Active\'';
  ```
- After any rename or new custom object, run a full deploy to a scratch org and execute all tests to catch missing prefixes before version create.

---

### 3. API Version Mismatch

**Error message:**

```
Entity type cannot be inserted, Component: ApexClass, Error: API version X is not supported
```

**Why it happens:** Individual metadata files carry their own `<apiVersion>` in their `-meta.xml` files. If a new class or trigger is created with an older API version than what `sfdx-project.json` specifies, or if Salesforce has retired that version, the deploy or version create fails.

**How to fix:**

1. Check the version declared in `sfdx-project.json`:
   ```json
   "sourceApiVersion": "66.0"
   ```
2. Make sure every `-meta.xml` file for classes and triggers matches:
   ```xml
   <apiVersion>66.0</apiVersion>
   ```
3. To bulk-update all files:
   ```bash
   grep -rl "<apiVersion>" force-app/ | xargs sed -i 's/<apiVersion>.*<\/apiVersion>/<apiVersion>66.0<\/apiVersion>/'
   ```
   On Windows (PowerShell):
   ```powershell
   Get-ChildItem -Recurse -Filter "*-meta.xml" | ForEach-Object {
     (Get-Content $_.FullName) -replace '<apiVersion>.*</apiVersion>', '<apiVersion>66.0</apiVersion>' |
     Set-Content $_.FullName
   }
   ```

---

### 4. Named Credential Callout Fails After Package Install

**Error message:**

```
System.CalloutException: Unauthorized endpoint, please add endpoint to Remote Site Settings or Named Credentials
```

**Why it happens:** The Named Credential (`Projetly_Webhook`) ships with a placeholder endpoint. If the subscriber org installs the package without updating the endpoint first, all outbound callouts fail immediately.

**How to fix:**

1. After installation, go to **Setup > Named Credentials > Projetly Webhook > Edit**.
2. Replace the endpoint with the live webhook URL.
3. Or redeploy the updated `Projetly_Webhook.namedCredential-meta.xml` with the correct URL.
4. Confirm the credential is reachable from within Salesforce by running the manual test from the **Testing** section above.

---

### 5. Custom Metadata Values Not Configured (Blank Secret / Key)

**Symptom:** Webhooks fire but the receiving server rejects them with `401 Unauthorized` or the signature check fails.

**Why it happens:** `Projetly_Config.Default` ships with placeholder values for `Webhook_Secret__c` and `Function_Key__c`. A blank or placeholder secret produces an incorrect HMAC signature on every outbound request.

**How to fix:**

1. Go to **Setup > Custom Metadata Types > Projetly Config > Manage Records > Default > Edit**.
2. Set `Webhook_Secret__c` to the HMAC signing key shared with your server.
3. Set `Function_Key__c` to the API key expected in the `x-functions-key` header.
4. Save — no deployment needed; Custom Metadata changes take effect immediately.

---

### 6. Package Version Create Hangs or Times Out

**Error message:**

```
Package version create request status: InProgress
... (no further output)
Request timed out. Run "sf package version create report" to check status.
```

**Why it happens:** The `--wait` flag sets a timeout in minutes. If scratch org provisioning is slow or test execution takes longer than the allotted time, the CLI exits but the job continues asynchronously in the Dev Hub.

**How to fix:**

1. Check the status of the in-progress request:
   ```bash
   sf package version create report --package-create-request-id <08c...ID>
   ```
2. If still running, wait and re-check. Scratch org spin-up typically takes 3–8 minutes.
3. Increase `--wait` to `20` or `30` for orgs with large test suites.
4. If the request failed (not just timed out), the report will show the error message — treat it as a fresh version create failure and apply the relevant fix above.
