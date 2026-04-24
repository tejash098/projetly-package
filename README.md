# Projetly 2GP Package

A Salesforce 2GP managed package that automatically delivers real-time webhook events to your external platform whenever Account, Contact, or Opportunity records are created, updated, or deleted — with zero configuration required after installation.

![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Version](https://img.shields.io/badge/version-0.1.0-orange)
![API Version](https://img.shields.io/badge/Salesforce%20API-v66.0-blue)
![Coverage](https://img.shields.io/badge/test%20coverage-85%25%2B-brightgreen)

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup & Deployment](#setup--deployment)
- [Configuration](#configuration)
- [Testing](#testing)

---

## Prerequisites

- **Salesforce CLI (`sf`)** — v2 or later
- **Node.js** — v18 or later (required by Salesforce CLI)
- **Git**
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
sf package install \
  --package 04tgK000000CRyvQAG \
  --target-org <your-org-alias> \
  --wait 10
```

All available versions:

| Build             | Package Version ID     |
| ----------------- | ---------------------- |
| 0.1.0-1           | ``   |
| 0.1.0-2           | ``   |
| 0.1.0-3           | ``   |
| 0.1.0-4           | ``   |
| 0.1.0-19 (latest) | `04tgK000000CRyvQAG`   |

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

| Field              | Purpose                                                      |
| ------------------ | ------------------------------------------------------------ |
| `Webhook_Secret__c` | HMAC-SHA256 signing key for outbound request signatures     |
| `Function_Key__c`  | API key sent as the `x-functions-key` header for endpoint auth |

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

### Test Coverage Summary

| Scenario                                      | Test Method                                        |
| --------------------------------------------- | -------------------------------------------------- |
| Account insert / update / delete              | `testAccountTrigger`                               |
| Contact insert / update / delete              | `testContactTrigger`                               |
| Opportunity insert / update / delete          | `testOpportunityFlow`                              |
| OCR insert / update / delete (Contact IDs)    | `testOCRTrigger`                                   |
| 200-record bulk insert                        | `testBulkOpportunities`                            |
| 50-record bulk delete in one payload          | `testBulkDelete`                                   |
| Successful callout                            | `testDirectSendBatch_success`                      |
| Failed callout (503 response)                 | `testDirectSendBatch_failure`                      |
| Empty record ID set (no-op)                   | `testDirectSendBatch_emptyIds`                     |
| Null record IDs (no-op)                       | `testDirectSendBatch_nullIds`                      |
| Retry on failure                              | `testRetryOnFailure`                               |
| Retry chain stops at attempt 3                | `testQueueableRetryChain`                          |
| Null IDs in queueable                         | `testQueueableNullIds`                             |
| Empty IDs in queueable                        | `testQueueableEmptyIds`                            |
| HMAC signature non-null and correct format    | `testGenerateSignature`                            |
| Signature is deterministic                    | `testGenerateSignature_deterministicOutput`        |
| Different inputs produce different signatures | `testGenerateSignature_differentInputsProduceDifferentOutput` |
| Webhook secret returned non-null              | `testGetWebhookSecret`                             |
| Function key returned non-null                | `testGetFunctionKey`                               |
| Post-install: new install                     | `testPostInstall_newInstall`                       |
| Post-install: upgrade path                    | `testPostInstall_upgrade`                          |
| Post-install: PS already assigned (no dup)   | `testPostInstall_alreadyAssigned`                  |