AKSHARA ERP

OWNER FUTURE PLATFORM IDEAS & RECONCILIATION QUEUE

Part 1 — Foundation, Global Rules & Items 1–5

⸻

Document Status

Status: OWNER REFERENCE DOCUMENT

Implementation Status: DO NOT IMPLEMENT

Roadmap Status: NOT YET RECONCILED

Execution Status: NONE

Authority Level: Owner Reminder & Future Reconciliation Source Only

⸻

Purpose

This document exists for one reason:

No important platform, architecture, provider, production-readiness or long-term SaaS idea should ever be forgotten during Akshara development.

During the project, many important ideas were identified while reviewing real-school operations, production SaaS architecture, scalability, provider abstraction, external integrations and future operational requirements.

Some of these ideas may already exist.

Some may already be partially implemented.

Some may already be covered by:

* PRC
* Production Readiness
* Existing Roadmap
* Existing Architecture
* Existing Source Code
* Existing Provider Abstractions

Therefore this document must NEVER be treated as an implementation backlog.

It is an Owner Reminder Queue.

⸻

THIS DOCUMENT IS NOT

This document is NOT:

* a roadmap
* an execution plan
* a sprint backlog
* a TODO list
* approval to build
* proof that something is missing

⸻

GOLDEN RULE

Every single idea inside this document must first pass through:

Current Code

↓

Evidence

↓

Architecture Audit

↓

PRC Reconciliation

↓

Roadmap Reconciliation

↓

Owner Approval

↓

Implementation

If any of those stages prove the capability already exists,

STOP.

Do not duplicate work.

⸻

GLOBAL REVIEW RULES

Every future review must follow these rules.

Rule 1

Current source code is the authority.

Never:

* memory
* chat history
* roadmap percentages
* assumptions

⸻

Rule 2

Every item must first be reconciled against:

* Current implementation
* Canonical Roadmap
* PRC
* Production Readiness
* Existing architecture
* Previous owner decisions

⸻

Rule 3

Every reviewed item must receive ONE status only.

Possible statuses:

* WORKING / LIVE
* COMPLETE
* PARTIAL
* HARDCODED
* PROVIDER-TIED
* CONFIG-ONLY
* UI ONLY
* MOCK
* STUB
* MISSING
* NOT APPLICABLE
* UNKNOWN / NOT PROVEN

⸻

Rule 4

Never implement because an item exists inside this document.

Presence in this document is NOT evidence.

⸻

Rule 5

Duplicate implementation is prohibited.

⸻

Rule 6

If current architecture already satisfies the requirement,

mark it

COMPLETE

and stop.

⸻

Rule 7

Every provider-related capability must answer one important question:

“If this provider changes tomorrow,

will Akshara require feature rewrites,

or only configuration changes?”

Configuration changes are preferred.

Feature rewrites are architectural debt.

⸻

Rule 8

Secrets must never be exposed.

API Keys

Passwords

Tokens

Private Certificates

must never appear in reports or documentation.

⸻

Rule 9

Business Logic

must never depend directly upon

vendor SDKs.

Use adapters.

⸻

Rule 10

Whenever possible,

Business Logic

↓

Shared Service

↓

Provider Adapter

↓

External Provider

Never:

Business Logic

↓

Provider SDK

⸻

PLATFORM PHILOSOPHY

Akshara is intended to become a long-term school ERP platform.

External providers will change.

APIs will change.

Pricing will change.

Schools will migrate.

Technology will evolve.

Therefore,

Business Features

must remain stable,

while

Providers

must remain replaceable.

⸻

ITEM 1

PAYMENT GATEWAY PROVIDER LAYER

Goal

Fee management and finance workflows must never require rewriting when payment providers change.

Changing

Razorpay

↓

Cashfree

↓

PhonePe

↓

Future Provider

must require configuration,

not feature redevelopment.

⸻

Audit First

Before implementing anything, verify:

* Current payment architecture
* Provider abstraction
* Webhook flow
* Finance integration
* Existing adapters
* Existing roadmap
* Existing payment models

⸻

Future Direction

Create one stable Akshara Payment Interface.

Business modules communicate only with that interface.

Provider-specific work belongs inside adapters.

⸻

Provider Examples

Examples include:

* Razorpay
* Cashfree
* PhonePe
* Future providers

This list is illustrative only.

⸻

Configuration

Future provider configuration should support:

* API credentials
* Merchant account
* Webhooks
* Test/Live mode
* Secret rotation
* Provider enable/disable
* Health checks
* Audit history

without changing finance modules.

⸻

Reconciliation Rule

Before roadmap integration verify:

* already implemented?
* partially abstracted?
* hardcoded?
* provider tied?
* UI only?
* mock?

Only verified gaps proceed.

⸻

ITEM 2

PUSH NOTIFICATION PROVIDER LAYER

Goal

Homework,

Attendance,

Fees,

Transport,

Communication,

Marketing,

AI,

must never depend directly upon one push provider.

⸻

Audit First

Inspect:

* FCM implementation
* notification services
* provider abstractions
* queues
* retries
* existing roadmap

⸻

Future Direction

One Notification Service.

Business modules publish notification intent.

Provider adapters deliver notifications.

⸻

Configuration

Provider settings should support:

* credentials
* enable/disable
* provider selection
* retry policy
* health
* delivery visibility

without feature rewrites.

⸻

Reconciliation Rule

Never build another notification system if abstraction already exists.

⸻

ITEM 3

EMAIL PROVIDER LAYER

Goal

Changing

SMTP

↓

SES

↓

Future Email Provider

must not require rewriting communication features.

⸻

Audit First

Verify:

* email services
* SMTP
* templates
* credentials
* secure storage
* provider coupling

⸻

Future Direction

One common email service.

Provider adapters only handle delivery.

Communication modules remain unchanged.

⸻

Configuration

Support future management of:

* sender
* domain
* credentials
* templates
* provider
* delivery failures
* audit history

through secure configuration.

⸻

Reconciliation Rule

Do not assume email capability is missing.

Verify first.

⸻

ITEM 4

FILE & MEDIA STORAGE PROVIDER LAYER

Goal

Akshara media must not permanently depend on one storage provider.

Examples:

* School Photos
* Homework
* Videos
* Certificates
* PDFs
* Circulars
* AI files
* Marketing assets

⸻

Audit First

Verify current:

* local storage
* VPS storage
* cloud storage
* storage abstraction
* signed URLs
* media architecture

⸻

Future Direction

Business modules should never know where files are physically stored.

Storage implementation belongs behind one storage interface.

⸻

Possible Providers

Examples:

* Local VPS
* S3-compatible storage
* Cloudflare R2
* Future storage providers

Illustrative only.

⸻

Configuration

Provider changes should support:

* buckets
* lifecycle
* quotas
* signed access
* credentials

through secure configuration,

not feature rewrites.

⸻

Reconciliation Rule

Reuse current architecture if already suitable.

⸻

ITEM 5

WHATSAPP PROVIDER LAYER

Goal

School communication must never become permanently tied to one WhatsApp provider.

⸻

Audit First

Determine:

* Does WhatsApp exist?
* Live?
* Mock?
* Stub?
* Planned?
* Existing roadmap?

⸻

Future Direction

Communication modules generate communication intent.

Provider adapters deliver through:

* Meta Cloud API
* BSP Provider
* Future Providers

without changing communication workflows.

⸻

Configuration

Future provider management should support:

* Business Account
* Phone Number
* Credentials
* Templates
* Webhooks
* Enable/Disable
* Delivery Status
* Audit History

using secure configuration.

⸻

Reconciliation Rule

Never create a second WhatsApp implementation.

Audit existing code first.

Implement only verified missing capability.

⸻

END OF PART 1

The next section (Part 2) continues with:

* Item 6 — OCR / Document Extraction Provider Layer
* Item 7 — Shared PDF / Document Template & Renderer Layer
* Item 8 — Video / Media Delivery Provider Layer
* Item 9 — Biometric Device Adapter Layer
* Item 10 — Payment Reconciliation Adapter Layer

PART 2 — ITEMS 6–10

⸻

ITEM 6

OCR / DOCUMENT EXTRACTION PROVIDER LAYER

Goal

Akshara must never become permanently dependent upon one OCR technology or one AI vision provider.

Curriculum Intelligence,

Question Paper Intelligence,

Document Processing,

Student document uploads,

Certificate digitization,

Scanned PDF processing,

must all consume one normalized extraction pipeline.

Changing OCR technology must never require rewriting downstream business logic.

⸻

Audit First

Before any implementation, inspect and classify:

* Local OCR implementation
* Tesseract integration
* AI Vision integration
* Cloud OCR services
* Language handling
* Confidence scoring
* Existing extraction pipeline
* Existing provenance model
* Existing roadmap
* Existing PRC overlap

Determine whether the current architecture already provides a provider abstraction.

⸻

Future Direction

Preserve one canonical extraction contract.

Business modules request:

Extract Document

↓

Extraction Service

↓

OCR / Vision Provider Adapter

↓

Normalized Extraction Result

↓

Curriculum / ERP consumers

Business modules must never directly depend upon provider-specific OCR output.

⸻

Possible Providers

Examples include:

* Local Tesseract
* AI Vision
* Cloud OCR
* Future OCR engines

Provider examples are illustrative only.

⸻

Configuration

Provider configuration should eventually support:

* provider selection
* language configuration
* confidence thresholds
* fallback policy
* extraction mode
* cost policy
* secure credentials where required

without rewriting curriculum or ERP features.

⸻

Reconciliation Rule

Never replace an existing working extraction architecture.

Audit first.

Implement only verified missing capability.

⸻

ITEM 7

SHARED PDF / DOCUMENT TEMPLATE & RENDERER LAYER

Goal

Akshara must not build independent PDF systems for every module.

Question Papers,

Circulars,

Certificates,

Letters,

Bonafide,

Transfer Certificate,

Fee Certificate,

Official Notices,

Reports,

should reuse one common document foundation.

⸻

Audit First

Inspect current:

* PDF generation
* Templates
* Renderer
* School branding
* Logo handling
* Header/footer
* Print support
* Existing reusable components
* Existing roadmap

⸻

Future Direction

One common pipeline:

School Identity Profile

↓

Document Template

↓

ERP / AI Data

↓

Preview

↓

Owner edits if required

↓

Approval

↓

Renderer

↓

PDF

↓

Print / Share / Archive

Question papers may use specialized layouts,

but the document foundation should remain shared.

⸻

School Identity

Future documents should automatically consume:

* School Name
* Logo
* Address
* Contact details
* Affiliation
* Academic Year
* Authorized Signatory
* Stamp
* Branding

from a central school profile,

rather than hardcoded templates.

Updating school information should automatically affect future generated documents where applicable.

⸻

Configuration

Templates should eventually support:

* school branding
* document layouts
* paper sizes
* headers
* footers
* signature placement
* watermark
* print configuration

through reusable template configuration,

not duplicated module code.

⸻

Reconciliation Rule

Verify whether reusable rendering already exists.

Avoid duplicate PDF engines.

⸻

ITEM 8

VIDEO / MEDIA DELIVERY PROVIDER LAYER

Goal

Large media delivery should not remain permanently tied to direct application storage.

School photos,

Videos,

Marketing content,

Gallery,

Event recordings,

Communication media,

should be capable of using different delivery architectures without rewriting consuming modules.

⸻

Audit First

Inspect:

* upload flow
* storage path
* download path
* playback
* signed URLs
* access control
* media permissions
* CDN usage
* existing roadmap

⸻

Future Direction

Separate:

Media Storage

from

Media Delivery.

Business modules should simply request media.

Provider-specific delivery belongs behind one media abstraction.

⸻

Possible Providers

Examples:

* Direct VPS
* CDN
* Future media delivery providers

Illustrative only.

⸻

Configuration

Future configuration should support:

* delivery provider
* caching policy
* URL expiry
* bandwidth controls
* signed access
* provider credentials

without changing gallery or communication modules.

⸻

Reconciliation Rule

If current architecture already satisfies these requirements,

reuse it.

⸻

ITEM 9

BIOMETRIC DEVICE ADAPTER LAYER

Goal

Attendance business logic must never be rewritten for every biometric hardware vendor.

Fingerprint,

Face Recognition,

Card Reader,

Future Attendance Devices,

should all normalize into one attendance model.

⸻

Audit First

Inspect:

* biometric integrations
* attendance ingestion
* vendor assumptions
* device registration
* synchronization
* health monitoring
* existing roadmap

⸻

Future Direction

Device

↓

Vendor Adapter

↓

Normalized Attendance Event

↓

Attendance Engine

↓

ERP

Attendance modules must never know which biometric vendor produced the event.

⸻

Normalized Event

Future canonical event fields may include:

* Device ID
* Student/Staff identity
* Timestamp
* Event Type
* Verification status
* Sync status
* Source

regardless of hardware vendor.

⸻

Configuration

Future configuration should support:

* device registration
* provider selection
* sync configuration
* enable/disable
* health monitoring
* diagnostics

through centralized management.

⸻

Reconciliation Rule

Reuse existing biometric abstractions wherever available.

⸻

ITEM 10

PAYMENT RECONCILIATION ADAPTER LAYER

Goal

Finance truth must remain independent from payment provider payloads.

Gateway-specific webhook structures must never leak into finance business logic.

⸻

Audit First

Inspect:

* webhook processing
* reconciliation
* UTR handling
* transaction mapping
* refund processing
* reversal handling
* finance integration
* existing roadmap
* existing PRC overlap

⸻

Future Direction

Gateway Event

↓

Provider Adapter

↓

Normalized Payment Event

↓

Finance Engine

↓

Ledger

↓

Reports

Finance should consume one canonical payment model.

⸻

Canonical Payment Model

Normalize provider data into common concepts such as:

* Transaction ID
* UTR
* Student
* Fee Record
* Amount
* Currency
* Status
* Timestamp
* Refund
* Reversal
* Reconciliation Evidence

Provider-specific terminology should remain inside adapters.

⸻

Configuration

Future configuration should support:

* webhook secrets
* provider credentials
* reconciliation policy
* retry policy
* diagnostics
* audit history

without changing finance workflows.

⸻

Reconciliation Rule

Do not replace existing finance architecture unless evidence proves a genuine provider-coupling gap.

⸻

END OF PART 2

The next section (Part 3) continues with:

* Item 11 — Accounting Export / Integration Adapter Layer
* Item 12 — Identity / Authentication Provider Layer
* Item 13 — AI Provider / Model Configuration Layer
* Item 14 — GPS / Vehicle Tracking Provider Layer (Locked Hybrid Architecture)
* Item 15 — Map Provider Layer (Locked Provider-Agnostic Architecture)

PART 3 — ITEMS 11–15

⸻

ITEM 11

ACCOUNTING EXPORT / INTEGRATION ADAPTER LAYER

Goal

Akshara Finance must never become permanently tied to one accounting package.

Schools may use:

* Tally
* Excel
* CSV
* Future Accounting Systems

Changing accounting software must not require rewriting Finance.

⸻

Audit First

Verify:

* Existing export formats
* Finance reports
* Ledger generation
* Accounting mappings
* Existing integrations
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

Finance Modules

↓

Canonical Finance Model

↓

Accounting Export Service

↓

Accounting Provider Adapter

↓

Target Accounting Software

Business logic owns financial truth.

Export adapters own provider-specific formats.

⸻

Configuration

Future configuration should support:

* Export format
* Account mappings
* Ledger mappings
* Tax mappings
* Financial year settings
* Provider-specific configuration

without changing Finance modules.

⸻

Reconciliation Rule

Reuse existing exports if already sufficient.

Never build duplicate export systems.

⸻

ITEM 12

IDENTITY / AUTHENTICATION PROVIDER LAYER

Goal

Identity Providers must remain independent from authorization and tenant resolution.

Current phone OTP authentication must not force future rewrites if Akshara later supports:

* Email Login
* Google Login
* Microsoft Login
* SSO
* Government Identity
* Future Identity Providers

⸻

Audit First

Inspect:

* Authentication
* OTP
* Session creation
* Role resolution
* Tenant resolution
* Multi-school support
* Existing provider abstractions
* Existing roadmap

⸻

Future Direction

Identity Provider

↓

Authentication Service

↓

Verified Identity

↓

Authorization

↓

Tenant Resolution

↓

Role Resolution

↓

ERP

Business authorization must never depend upon a specific login provider.

⸻

Configuration

Future configuration should support:

* Provider enable/disable
* Authentication priority
* Login policies
* Session settings
* Security controls
* Provider credentials

through centralized secure management.

⸻

Reconciliation Rule

Audit current authentication first.

Do not redesign if provider abstraction already exists.

⸻

ITEM 13

AI PROVIDER / MODEL CONFIGURATION LAYER

Goal

Akshara AI capabilities must remain provider-agnostic.

Changing:

* OpenAI
* OpenRouter
* Future AI Providers

must not require rewriting AI-enabled features.

⸻

Audit First

Inspect:

* AI routing
* Provider selection
* Model selection
* API key storage
* Token accounting
* School limits
* Platform limits
* Existing AI settings
* Existing roadmap

⸻

Future Direction

AI Features

↓

AI Service

↓

Provider Router

↓

Provider Adapter

↓

Selected Model

↓

Response

Business modules must never directly depend upon provider SDKs.

⸻

Configuration

Future configuration should support:

* Provider selection
* Model selection
* API Keys
* Limits
* Budgets
* Recharge
* Token monitoring
* Fallback models
* Health status

through secure centralized configuration.

⸻

Security

Secrets must never:

* appear in source code
* appear in logs
* appear in client applications
* appear in audit exports

⸻

Reconciliation Rule

Verify the existing AI Control Center before proposing new architecture.

⸻

ITEM 14

GPS / VEHICLE TRACKING PROVIDER LAYER

LOCKED PRODUCT DIRECTION

⸻

Goal

Dedicated GPS hardware must NOT be mandatory.

Akshara targets:

* Small Schools
* Village Schools
* Budget Schools
* Medium Schools
* Enterprise Schools

The transport architecture must support all of them.

⸻

LOCKED HYBRID MODEL

Akshara supports multiple tracking sources through one normalized tracking architecture.

Supported sources:

* Driver Mobile GPS
* Dedicated GPS Device
* GPS Vendor Integration

All feed one common Vehicle Location Stream.

⸻

Driver Mobile GPS

Flow:

Authorized Driver Login

↓

Assigned Vehicle

↓

Assigned Route

↓

Start Trip

↓

Location Sharing Begins

↓

Phone becomes Active GPS Source

↓

Background Location Updates

↓

Parent & School Tracking

↓

End Trip

↓

Tracking Stops

No dedicated hardware required.

⸻

Driver Replacement

When a driver changes:

Old Driver

↓

Authority Revoked

↓

Substitute Driver Assigned

↓

Route transferred

↓

Substitute Starts Trip

↓

Substitute Phone becomes Active Source

↓

Old Source Rejected

↓

Audit History Recorded

⸻

Dedicated GPS

Schools already using GPS devices may continue using them.

Dedicated devices remain:

OPTIONAL

They are never mandatory for Akshara adoption.

⸻

Vendor Tie-up

Future vendor partnerships may be explored.

Akshara itself should not require schools to purchase hardware.

⸻

Configuration

School-level tracking mode should eventually support:

* Driver Mobile GPS
* Dedicated GPS Device
* Vendor Integration

⸻

Reconciliation Rule

Before implementation verify:

* Existing transport architecture
* Existing GPS support
* Existing roadmap
* Existing transport audits

Only verified gaps proceed.

⸻

ITEM 15

MAP PROVIDER LAYER

LOCKED PRODUCT DIRECTION

⸻

Goal

GPS source and Map Provider are separate concerns.

Changing map providers must never require rewriting transport business logic.

⸻

Future Direction

Transport Modules

↓

Akshara Map Interface

↓

Map Provider Adapter

↓

Map Provider

↓

Rendered Map

⸻

Possible Providers

Examples include:

* MapLibre
* OpenStreetMap
* Google Maps
* Future Providers

The list is illustrative only.

⸻

Locked Principle

Map provider selection must be configuration-driven.

Transport workflows remain unchanged.

⸻

Parent Tracking Experience

Where supported, the parent/school map should display:

* Route
* Moving Bus Marker
* Student Stop
* Bus Stops
* Vehicle freshness
* Offline/Stale status
* ETA (only when reliable)

⸻

Configuration

Future provider configuration may include:

* API Keys
* Tile Provider
* Style
* Routing
* Geocoding
* Enable/Disable
* Usage Controls

Securely managed without feature rewrites.

⸻

Reconciliation Rule

Audit current map implementation first.

Reuse existing abstractions where available.

Do not duplicate map infrastructure.

⸻

END OF PART 3

The next section (Part 4) continues with:

* Item 16 — SMS / OTP Provider Layer
* Item 17 — School Website / Custom Domain Layer
* Item 18 — Backup Storage Provider Layer
* Item 19 — Analytics / Observability Provider Layer
* Item 20 — Digital Signature / eSign Provider Layer

PART 4 — ITEMS 16–20

⸻

ITEM 16

SMS / OTP PROVIDER LAYER

Goal

Akshara must never become permanently coupled to one SMS provider.

Changing an SMS provider or business account must require secure configuration changes rather than rewriting authentication or notification features.

⸻

Verified Current Context

The current audit established the following verified facts:

* Live OTP currently uses Fast2SMS.
* The implementation is partially abstracted but practically Fast2SMS-coupled.
* API-key-only replacement is CONDITIONAL.
* Existing Super Admin SMS configuration is not currently the live OTP authority.
* Schools currently share one platform-owned SMS account.
* School-wise SMS quota enforcement is not yet verified as complete.

These findings are evidence from the audit and must be reconciled with future implementation work.

⸻

Audit First

Before implementing anything, inspect:

* OTP generation
* OTP verification
* SMS delivery
* Provider abstraction
* Provider adapters
* Secret storage
* VPS environment
* Super Admin settings
* School settings
* Existing roadmap
* PRC overlap

⸻

Future Direction

Authentication Modules

↓

OTP Service

↓

SMS Service

↓

Provider Adapter

↓

SMS Provider

Business modules should never directly communicate with provider APIs.

⸻

Provider Examples

Illustrative examples:

* Fast2SMS
* MSG91
* Twilio
* Future Providers

The architecture must not depend upon any specific vendor.

⸻

Configuration

Future provider configuration should support:

* API credentials
* Sender ID
* Template IDs
* DLT configuration
* Route selection
* Provider enable/disable
* Test mode
* Production mode
* Delivery diagnostics
* Credential rotation

through secure centralized management.

⸻

School Architecture

Audit and preserve a clear distinction between:

* Platform-owned SMS account
* School-owned SMS account (if ever supported)

Business logic must remain unchanged regardless of account ownership.

⸻

Reconciliation Rule

Reconcile this item against:

* Existing audit findings
* PRC
* Current implementation
* Existing roadmap

Do not rebuild SMS infrastructure if suitable abstraction already exists.

⸻

ITEM 17

SCHOOL WEBSITE / CUSTOM DOMAIN LAYER

Goal

School identity and public web presence must not require custom coding for every school.

Each school should be capable of maintaining its own identity while remaining inside the Akshara platform.

⸻

Audit First

Inspect:

* Existing branding
* Tenant identity
* Domain handling
* School profile
* Public pages
* Existing roadmap

⸻

Clarification

This item concerns:

Public Website

School Branding

Custom Domain

Subdomain

It does NOT refer to authenticated Browser ERP.

Those are separate capabilities.

⸻

Future Direction

Platform

↓

Tenant Identity

↓

Brand Configuration

↓

Domain Configuration

↓

Public Website

↓

Visitors

School branding should remain configuration-driven.

⸻

Configuration

Future configuration may support:

* School logo
* School colors
* Custom domain
* Platform subdomain
* Contact information
* Social links
* Branding assets

without custom software development.

⸻

Reconciliation Rule

Audit current capabilities before assuming custom-domain support is missing.

⸻

ITEM 18

BACKUP STORAGE PROVIDER LAYER

Goal

Backup and disaster recovery must not depend upon one storage destination.

Changing backup providers should never require rewriting application modules.

⸻

Audit First

Inspect:

* Current backups
* PITR
* WAL
* Backup destinations
* Restore procedures
* Existing roadmap
* Production readiness

⸻

Future Direction

Application Data

↓

Backup Service

↓

Backup Adapter

↓

Backup Destination

↓

Restore

The application should remain independent from backup provider implementation.

⸻

Configuration

Future backup configuration may support:

* Backup destination
* Retention policy
* Encryption
* Restore testing
* Integrity verification
* Schedule
* Notifications

through centralized administration.

⸻

Reconciliation Rule

This item must be reconciled with existing production-readiness work before adding new implementation.

⸻

ITEM 19

ANALYTICS / OBSERVABILITY PROVIDER LAYER

Goal

Production monitoring must remain independent from any single observability vendor.

Business modules should emit telemetry through common platform services.

⸻

Audit First

Inspect:

* Logging
* Metrics
* Tracing
* Crash reporting
* Alerting
* Existing monitoring
* Existing roadmap

⸻

Future Direction

Business Modules

↓

Telemetry Service

↓

Provider Adapter

↓

Monitoring Provider

↓

Dashboards & Alerts

⸻

Possible Providers

Illustrative examples:

* Sentry
* Prometheus
* Future monitoring platforms

Provider choice must not affect business logic.

⸻

Configuration

Future configuration may support:

* Provider selection
* Alert routing
* Environment separation
* Health monitoring
* Retention
* Sampling policies

through centralized configuration.

⸻

Reconciliation Rule

This item overlaps existing production-readiness work.

Avoid duplicate implementation.

⸻

ITEM 20

DIGITAL SIGNATURE / ESIGN PROVIDER LAYER

Goal

Future document signing capability must remain independent from document generation.

Question papers,

Certificates,

Official documents,

Approvals,

must be generated independently from whichever digital-signature provider is selected.

⸻

Audit First

Inspect:

* Current document approvals
* Existing signatures
* Existing certificates
* Existing roadmap
* Regulatory assumptions

⸻

Future Direction

Document

↓

Signing Service

↓

Provider Adapter

↓

Digital Signature Provider

↓

Signed Document

Document generation must not depend upon signing technology.

⸻

Configuration

Future signing configuration may support:

* Authorized signatories
* Signing provider
* Certificate configuration
* Signing policy
* Audit evidence
* Verification status

through secure centralized administration.

⸻

Legal Note

Do not assume legal validity simply because a signing provider exists.

Applicable regulatory and legal requirements must be verified before certification.

⸻

Reconciliation Rule

Audit first.

Only verified missing capability may enter the roadmap.

⸻

END OF PART 4

The next section (Part 5) continues with:

* Item 21 — Search Provider / Search Engine Layer
* Item 22 — Background Job / Queue Execution Layer
* Item 23 — Central Scheduler / Cron Engine Layer
* Item 24 — Communication Channel Orchestrator
* Item 25 — Common Webhook / External Event Ingestion Framework

PART 5 — ITEMS 21–25

⸻

ITEM 21

SEARCH PROVIDER / SEARCH ENGINE LAYER

Goal

Akshara search capability must remain independent from any single search technology.

Student Search,

Staff Search,

Fee Search,

Document Search,

Curriculum Search,

Question Bank Search,

Transport Search,

and every future search feature should consume one common search interface.

Changing search technology must never require rewriting business modules.

⸻

Audit First

Inspect:

* Existing database search
* Full-text search
* Module-specific search logic
* Existing indexing
* Existing roadmap
* Existing production architecture

⸻

Future Direction

Business Modules

↓

Search Service

↓

Search Provider Adapter

↓

Search Engine

↓

Results

Business modules must never know which search engine produced the results.

⸻

Possible Providers

Illustrative examples:

* Native Database Search
* Meilisearch
* OpenSearch
* Elasticsearch
* Future Engines

⸻

Configuration

Future configuration may support:

* Search provider
* Index configuration
* Ranking
* Tenant isolation
* Filters
* Pagination
* Re-indexing policies

without feature rewrites.

⸻

Reconciliation Rule

Do not introduce an external search engine unless evidence proves the current solution is insufficient.

⸻

ITEM 22

BACKGROUND JOB / QUEUE EXECUTION LAYER

Goal

Long-running work must never depend upon request lifecycle or fragile in-process execution.

Examples:

* OCR
* AI Tasks
* Bulk Notifications
* PDF Generation
* Exports
* Imports
* Media Processing

must execute through one reliable background-job architecture.

⸻

Audit First

Inspect:

* Existing async work
* Queues
* Workers
* Retry handling
* Existing roadmap
* Existing production readiness

⸻

Future Direction

Business Module

↓

Job Submission

↓

Queue

↓

Worker

↓

Execution

↓

Result

Business modules submit work.

Workers perform work.

⸻

Job Requirements

Future canonical job model should support:

* Job ID
* Tenant
* Priority
* Retry
* Timeout
* Cancellation
* Progress
* Failure Reason
* Idempotency
* Audit Evidence

⸻

Possible Implementations

Illustrative examples:

* In-process
* Redis Queue
* Dedicated Workers
* Future Queue Providers

Architecture should remain provider-independent.

⸻

Reconciliation Rule

Audit first.

Do not replace an existing durable queue architecture without evidence.

⸻

ITEM 23

CENTRAL SCHEDULER / CRON ENGINE LAYER

Goal

Timed operations must never implement independent scheduling logic inside every module.

Examples:

* Fee reminders
* Attendance reminders
* Birthday wishes
* Bus departure reminders
* Daily reports
* Weekly reports
* Monthly jobs
* Backups

should all use one scheduling framework.

⸻

Audit First

Inspect:

* Existing cron jobs
* Scheduled tasks
* Timers
* Existing scheduler
* Existing roadmap

⸻

Future Direction

Business Module

↓

Scheduling Service

↓

Scheduler

↓

Execution

↓

Job

Modules express intent.

Scheduler controls execution.

⸻

Scheduler Responsibilities

Future scheduler should eventually support:

* Recurring jobs
* One-time jobs
* Timezone awareness
* School calendar awareness
* Retry
* Duplicate prevention
* Enable/Disable
* Last run
* Next run
* Execution evidence

⸻

Reconciliation Rule

Never create multiple scheduling systems.

⸻

ITEM 24

COMMUNICATION CHANNEL ORCHESTRATOR

Goal

Business modules must never directly call:

* SMS
* Email
* WhatsApp
* Push Notification

Instead,

business events should pass through one communication orchestration layer.

⸻

Audit First

Inspect:

* Existing notification flow
* SMS
* Push
* Email
* WhatsApp
* Existing roadmap

⸻

Future Direction

Business Event

↓

Communication Policy

↓

Recipient Resolution

↓

Channel Selection

↓

Provider Adapter

↓

Delivery

Example:

Fee Overdue

↓

Push

↓

If failed

↓

WhatsApp

↓

If failed

↓

SMS

All governed centrally.

⸻

Policy Examples

Different schools may choose different communication policies.

Examples:

School A:

Push only

School B:

Push + WhatsApp

School C:

SMS only

Business modules remain unchanged.

⸻

Configuration

Future configuration may support:

* Channel priority
* Retry
* Quiet hours
* Consent
* Escalation
* Cost policy
* Delivery evidence

through centralized policy.

⸻

Reconciliation Rule

This orchestrator composes existing provider layers.

It must never duplicate SMS, Email or Push implementations.

⸻

ITEM 25

COMMON WEBHOOK / EXTERNAL EVENT INGESTION FRAMEWORK

Goal

Every external integration must not reinvent webhook handling.

Examples:

* Payment Gateway
* GPS Vendor
* Biometric Device
* WhatsApp
* Future Providers

should all enter through one common ingestion architecture.

⸻

Audit First

Inspect:

* Existing webhook endpoints
* Signature verification
* Replay protection
* Deduplication
* Existing roadmap
* Existing production architecture

⸻

Future Direction

External Provider

↓

Webhook Gateway

↓

Verification

↓

Normalization

↓

Event Routing

↓

Business Modules

⸻

Responsibilities

Future webhook framework should support:

* Signature verification
* Timestamp validation
* Replay protection
* Deduplication
* Retry
* Failure handling
* Audit evidence
* Provider identification

⸻

Security

Sensitive payloads must be protected.

Secret verification must never occur inside business modules.

⸻

Reconciliation Rule

Audit existing integrations first.

Reuse any shared webhook infrastructure already present.

⸻

END OF PART 5

The next section (Part 6) continues with:

* Item 26 — Central Secrets / API Key Vault & Rotation Layer
* Item 27 — Feature Flag / Capability Entitlement Layer
* Item 28 — Data Import / Legacy ERP Migration Adapter Layer
* Item 29 — File Upload Validation / Malware Safety Pipeline
* Item 30 — Translation / Language Service Layer

PART 6 — ITEMS 26–30

⸻

ITEM 26

CENTRAL SECRETS / API KEY VAULT & ROTATION LAYER

Goal

Akshara must have one secure, centralized architecture for managing platform secrets.

External providers should never store credentials inconsistently across:

* Source Code
* Random Environment Variables
* Client Applications
* Individual Module Settings
* Hardcoded Configuration

The objective is to make secret management secure, auditable and maintainable.

⸻

Audit First

Inspect current handling of:

* AI API Keys
* SMS Provider Keys
* Payment Gateway Secrets
* Map Provider Keys
* Email Credentials
* WhatsApp Credentials
* GPS Vendor Credentials
* Database Secrets
* Existing Vault Architecture
* Existing Roadmap
* Existing PRC overlap

⸻

Future Direction

Business Module

↓

Shared Service

↓

Secret Reference

↓

Central Secret Management

↓

Provider Adapter

↓

External Provider

Business modules must never directly know provider credentials.

⸻

Secret Management Responsibilities

Future architecture should support:

* Secure Storage
* Encryption
* Rotation
* Revocation
* Expiry
* Version History
* Audit History
* Access Control
* Secret Masking
* Runtime Retrieval

⸻

Scope Separation

Clearly distinguish:

Platform Secrets

School Secrets (if supported)

Environment Secrets

Temporary Credentials

Future architecture must preserve separation of responsibility.

⸻

Reconciliation Rule

This item must reconcile with:

* Existing AI Control Center
* Existing SMS audit findings
* Existing deployment architecture

Do not duplicate existing secure secret-management work.

⸻

ITEM 27

FEATURE FLAG / CAPABILITY ENTITLEMENT LAYER

Goal

Akshara should enable or disable capabilities through configuration,

not through code branches.

Examples include:

* AI
* Transport
* Finance
* Homework
* Marketing
* Experimental Features
* Beta Rollouts

⸻

Audit First

Inspect:

* Existing plan handling
* Module visibility
* Feature switches
* Existing roadmap
* Existing SaaS architecture

⸻

Future Direction

Capability Request

↓

Entitlement Service

↓

Platform Policy

↓

Plan Policy

↓

School Override

↓

Effective Capability

↓

Business Module

⸻

Typical Scenarios

Examples:

School A

Transport Enabled

School B

Transport Disabled

Pilot Schools

New Feature Enabled

Production Schools

Stable Features Only

No module should require deployment changes for these decisions.

⸻

Configuration

Future entitlement configuration may support:

* Platform Defaults
* SaaS Plans
* School Overrides
* Pilot Groups
* Emergency Kill Switch
* Dependency Rules

⸻

Reconciliation Rule

Do not scatter hardcoded school-specific conditions throughout the application.

⸻

ITEM 28

DATA IMPORT / LEGACY ERP MIGRATION ADAPTER LAYER

Goal

Every new school should not require custom migration scripts.

Existing school data should enter Akshara through one controlled migration architecture.

⸻

Audit First

Inspect:

* Student Imports
* Parent Imports
* Staff Imports
* Fee Imports
* Excel Imports
* CSV Imports
* Existing bootstrap tools
* Existing roadmap

⸻

Future Direction

Source File

↓

Import Adapter

↓

Validation

↓

Preview

↓

Owner Confirmation

↓

Migration

↓

Results

↓

Audit

⸻

Migration Responsibilities

Future import architecture should support:

* Field Mapping
* Validation
* Duplicate Detection
* Conflict Detection
* Preview
* Rollback where appropriate
* Row-level Errors
* Import Audit

⸻

Supported Sources

Illustrative examples:

* Excel
* CSV
* Legacy ERP
* Future Import Providers

⸻

Reconciliation Rule

Do not bypass validation simply because a source is trusted.

Every import must pass through the canonical import pipeline.

⸻

ITEM 29

FILE UPLOAD VALIDATION / MALWARE SAFETY PIPELINE

Goal

Uploaded files must never move directly into production workflows.

Examples:

* Homework Files
* Photos
* PDFs
* Excel Files
* Documents
* Certificates
* Marketing Assets

must pass through one common safety pipeline.

⸻

Audit First

Inspect:

* Upload Flow
* MIME Validation
* Extension Validation
* File Size Policy
* Existing Scanning
* Existing Roadmap

⸻

Future Direction

Upload

↓

Validation

↓

Content Verification

↓

Safety Checks

↓

Quarantine (if required)

↓

Approved Storage

↓

Business Module

⸻

Validation Responsibilities

Future pipeline may support:

* Extension Verification
* MIME Verification
* Content Verification
* Filename Normalization
* Malware Scanning
* Image Validation
* Archive Safety
* OCR Eligibility
* Safe Promotion

⸻

Reconciliation Rule

File safety must remain centralized.

Business modules should never independently validate uploads.

⸻

ITEM 30

TRANSLATION / LANGUAGE SERVICE LAYER

Goal

Akshara multilingual support must distinguish between different translation responsibilities.

These include:

* UI Translation
* School-authored Content
* AI Translation
* Official Documents
* Notifications
* Curriculum Context

These should not be mixed together.

⸻

Audit First

Inspect:

* Existing multilingual support
* Translation resources
* AI translation
* Language handling
* Existing roadmap

⸻

Future Direction

Content

↓

Translation Service

↓

Translation Provider

↓

Normalized Translation Result

↓

Business Module

⸻

Translation Context

Future architecture should preserve:

* Source Language
* Target Language
* Content Type
* Glossary
* Domain Context
* Translation Provider
* Confidence
* Review State

⸻

Possible Providers

Illustrative examples:

* Local Dictionaries
* AI Translation
* Cloud Translation
* Future Providers

Business modules remain provider-independent.

⸻

Reconciliation Rule

Do not confuse:

Curriculum Language

with

Application Translation.

They are separate architectural concerns.

⸻

END OF PART 6

The next section (Part 7) continues with:

* Item 31 — Central Date / Time / Academic Calendar Rules Engine
* Item 32 — Central Money / Decimal / Rounding / Currency Rules Engine
* Item 33 — Shared Report / Export Adapter Layer
* Item 34 — Common Audit / Event History Framework
* Item 35 — School Policy / Business Rules Engine

PART 7 — ITEMS 31–35

⸻

ITEM 31

CENTRAL DATE / TIME / ACADEMIC CALENDAR RULES ENGINE

Goal

All date, time and calendar calculations must be handled consistently across Akshara.

Business modules must never independently implement date arithmetic or academic calendar rules.

This applies to:

* Attendance
* Fees
* Finance
* Payroll
* Exams
* Homework
* Transport
* Notifications
* Reports
* AI workflows
* Future modules

⸻

Audit First

Inspect:

* Existing date calculations
* Time handling
* Timezone handling
* Academic year logic
* Financial year logic
* Holiday handling
* Working day calculations
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

Business Module

↓

Shared Date & Calendar Service

↓

Academic Calendar

↓

Business Decision

↓

Result

Business modules ask the shared service for date decisions.

⸻

Shared Responsibilities

Future centralized rules may include:

* Local timezone
* UTC conversion
* Academic Year
* Financial Year
* Leap Year
* Month End
* Quarter End
* School Working Days
* Holidays
* Examination Days
* Weekend Policies
* Due Dates
* Grace Period Dates
* Recurring Dates

⸻

School Flexibility

Different schools may maintain different:

* Holidays
* Academic calendars
* Working Saturdays
* Examination calendars

These differences should be data/configuration,

not application code.

⸻

Reconciliation Rule

This item strongly overlaps Product Correctness and Edge Case Certification.

Never duplicate existing correctness work.

⸻

ITEM 32

CENTRAL MONEY / DECIMAL / ROUNDING / CURRENCY RULES ENGINE

Goal

Every financial calculation inside Akshara must follow one canonical monetary model.

Business modules must never perform independent floating-point calculations.

This applies to:

* Fees
* Payroll
* Transport Charges
* Discounts
* Taxes
* Refunds
* Fine Calculations
* Ledger
* Reports

⸻

Audit First

Inspect:

* Money types
* Decimal handling
* Rounding
* Currency assumptions
* Refund logic
* Existing finance implementation
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

Business Module

↓

Money Service

↓

Shared Monetary Rules

↓

Calculated Result

↓

Finance

⸻

Shared Responsibilities

Future centralized money rules may include:

* Decimal Precision
* Currency
* Rounding Mode
* Tax Rounding
* Discount Allocation
* Partial Payments
* Overpayments
* Refunds
* Reversals
* Negative Values
* Ledger Precision
* Reconciliation Tolerances

⸻

Scope

Current product scope assumes INR.

Future international support should remain possible,

without over-engineering multi-currency today.

⸻

Reconciliation Rule

Never scatter monetary calculations throughout modules.

Use one canonical financial calculation model.

⸻

ITEM 33

SHARED REPORT / EXPORT ADAPTER LAYER

Goal

Every module must not reinvent export functionality.

Examples include:

* Student Reports
* Fee Reports
* Attendance Reports
* Finance Reports
* Transport Reports
* Marketing Reports
* AI Reports
* Future Reports

⸻

Audit First

Inspect:

* Existing PDF exports
* Excel exports
* CSV exports
* Print support
* Existing report engine
* Existing roadmap

⸻

Future Direction

Business Module

↓

Canonical Report Dataset

↓

Export Service

↓

Export Adapter

↓

Requested Format

Business modules own report meaning.

Export adapters own formatting.

⸻

Supported Outputs

Future adapters may support:

* PDF
* XLSX
* CSV
* Print
* Future formats

Large reports should integrate with the Background Job layer.

⸻

Reconciliation Rule

Reuse the shared PDF/document foundation where applicable.

Do not duplicate rendering logic.

⸻

ITEM 34

COMMON AUDIT / EVENT HISTORY FRAMEWORK

Goal

Akshara should consistently answer:

Who?

Did What?

When?

Where?

Why?

What Changed?

Every sensitive or operational action should produce reliable audit evidence.

⸻

Audit First

Inspect:

* Existing audit logs
* Activity history
* Entity history
* Security logs
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

Business Action

↓

Audit Service

↓

Audit Record

↓

Immutable Storage

↓

Authorized Review

⸻

Future Audit Fields

Examples include:

* Actor
* Role
* Tenant
* Entity Type
* Entity ID
* Timestamp
* Action
* Before State
* After State
* Safe Difference
* Client
* Correlation ID
* Reason
* Approval Reference

⸻

Examples

Examples include:

* Student edited
* Fee changed
* Driver reassigned
* Route changed
* Certificate approved
* Provider configuration updated
* Secret rotation metadata
* Policy updated

Sensitive secret values must never appear in audit records.

⸻

Reconciliation Rule

Differentiate:

Security Audit

from

Business Event Processing.

Do not merge unrelated concepts.

⸻

ITEM 35

SCHOOL POLICY / BUSINESS RULES ENGINE

Goal

Legitimate operational differences between schools should be represented as configurable policies,

not hardcoded application logic.

⸻

Audit First

Inspect:

* School settings
* Existing policy handling
* Existing configuration
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

Business Module

↓

Policy Service

↓

Platform Default

↓

Plan Rules

↓

School Policy

↓

Authorized Override

↓

Effective Rule

↓

Business Decision

⸻

Policy Examples

Examples include:

* Attendance Late Time
* Fee Grace Period
* Notification Escalation
* Approval Thresholds
* Transport Tracking Mode
* Homework Policies
* Leave Approval Rules
* Examination Policies
* Finance Limits
* School-specific operational preferences

⸻

Versioning

Future policy architecture should support:

* Effective Date
* Version History
* Audit History
* Rollback where appropriate

without requiring code changes.

⸻

Reconciliation Rule

Avoid building an overly generic rules engine without evidence.

Start with typed, well-defined business policies and expand only when justified.

⸻

END OF PART 7

The next section (Part 8) continues with:

* Item 36 — License / Subscription Engine
* Item 37 — Organization / Multi-Tenant Isolation
* Item 38 — Approval Workflow Engine
* Item 39 — Workflow / State Machine Engine
* Item 40 — Public API / Integration Platform

It also contains the final global reconciliation principles, owner guidance, and document closing statements.

PART 8 — ITEMS 36–40, FINAL RECONCILIATION PRINCIPLES & OWNER CLOSING NOTES

⸻

ITEM 36

LICENSE / SUBSCRIPTION / SAAS ENTITLEMENT ENGINE

Goal

Akshara should manage SaaS subscriptions through one centralized entitlement architecture.

Business modules must never independently decide whether a school has access to a capability.

⸻

Audit First

Inspect:

* Existing subscription model
* SaaS plans
* Trial handling
* Existing quotas
* Existing roadmap
* Existing PRC overlap

⸻

Future Direction

School

↓

Subscription Service

↓

Plan

↓

Entitlements

↓

Business Modules

⸻

Examples

Future entitlement decisions may include:

* Trial
* Trial Expiry
* Grace Period
* Active Subscription
* Student Limits
* Staff Limits
* Storage Limits
* AI Credits
* SMS Credits
* Future Usage Credits

⸻

Reconciliation Rule

This item must compose with the Feature Flag / Capability Entitlement Layer.

Avoid duplicate entitlement logic.

⸻

ITEM 37

ORGANIZATION / MULTI-TENANT ISOLATION

Goal

Every school must remain completely isolated from every other school.

Tenant isolation must be enforced consistently across the entire platform.

⸻

Audit First

Inspect:

* Database isolation
* RLS
* Storage isolation
* Search
* AI context
* Reports
* Notifications
* Background jobs
* Backups
* Existing roadmap

⸻

Future Direction

Request

↓

Tenant Resolution

↓

Authorization

↓

Tenant Context

↓

Business Module

↓

Tenant-safe Data Access

⸻

Areas to Verify

Tenant isolation should be verified for:

* Students
* Parents
* Staff
* Finance
* Transport
* Files
* AI
* Reports
* Search
* Notifications
* Audit Logs

⸻

Reconciliation Rule

Do not assume isolation simply because authentication succeeds.

Evidence is required.

⸻

ITEM 38

APPROVAL WORKFLOW ENGINE

Goal

Approval logic should be reusable across Akshara.

Business modules should not each implement separate approval workflows.

⸻

Audit First

Inspect:

* Existing approvals
* Existing authorization
* Existing workflows
* Existing roadmap

⸻

Future Direction

Request

↓

Approval Engine

↓

Approver Resolution

↓

Decision

↓

Audit

↓

Business Module

⸻

Example Use Cases

Illustrative examples:

* Leave Approval
* Fee Waiver
* Certificate Approval
* Purchase Approval
* Transport Request
* Staff Requests
* Future Approval Workflows

⸻

Responsibilities

Future approval architecture may support:

* Multi-level Approval
* Delegation
* Escalation
* Expiry
* Audit History
* Comments
* Notifications

⸻

Reconciliation Rule

Reuse existing authorization wherever possible.

Approval is an extension of authorization,

not a replacement.

⸻

ITEM 39

WORKFLOW / STATE MACHINE ENGINE

Goal

Entity lifecycle management should be consistent.

Business modules should not invent arbitrary status values independently.

⸻

Audit First

Inspect:

* Existing entity statuses
* Existing lifecycle handling
* Existing roadmap

⸻

Future Direction

Entity

↓

Workflow Engine

↓

Allowed Transition

↓

Validation

↓

Audit

↓

New State

⸻

Example

Admission

Draft

↓

Submitted

↓

Verified

↓

Approved

↓

Joined

↓

Archived

⸻

Certificate

Requested

↓

Approved

↓

Generated

↓

Delivered

↓

Archived

⸻

Responsibilities

Future workflow architecture may support:

* Transition Validation
* Authorized Transitions
* History
* Rollback Rules
* Expiry
* Automation
* Notifications

⸻

Reconciliation Rule

Use workflows only where lifecycle complexity justifies them.

Avoid unnecessary abstraction.

⸻

ITEM 40

PUBLIC API / INTEGRATION PLATFORM

Goal

Akshara should eventually expose stable, secure external integration capabilities without exposing internal architecture.

⸻

Audit First

Inspect:

* Existing APIs
* Existing integrations
* Authentication
* Existing roadmap

⸻

Future Direction

External System

↓

Public Integration API

↓

Authentication

↓

Validation

↓

Business Services

↓

ERP

⸻

Possible Consumers

Illustrative examples:

* LMS
* Accounting Systems
* Government Systems
* School Websites
* Mobile Apps
* Future Third-party Integrations

⸻

Responsibilities

Future integration platform may support:

* Versioning
* Authentication
* Authorization
* Rate Limiting
* API Keys
* Webhooks
* Audit History
* Documentation

⸻

Reconciliation Rule

Do not expose internal implementation details.

Public integration contracts should remain stable while internal architecture evolves.

⸻

GLOBAL RECONCILIATION PRINCIPLES

Every item in this document must follow the same review process.

Phase 1

Audit Current Code

⸻

Phase 2

Collect Evidence

⸻

Phase 3

Reconcile Against:

* Canonical Roadmap
* PRC
* Production Readiness
* Existing Architecture
* Existing Documentation
* Previous Owner Decisions

⸻

Phase 4

Classify

Exactly one classification:

* COMPLETE
* WORKING / LIVE
* PARTIAL
* HARDCODED
* PROVIDER-TIED
* CONFIG-ONLY
* UI ONLY
* MOCK
* STUB
* MISSING
* NOT APPLICABLE
* UNKNOWN / NOT PROVEN

⸻

Phase 5

Only VERIFIED missing capability may enter the roadmap.

⸻

Phase 6

Owner Approval

⸻

Phase 7

Implementation

⸻

GLOBAL ARCHITECTURAL PHILOSOPHY

The objective of Akshara is not to integrate every provider.

The objective is to ensure that changing providers, vendors, infrastructure, or operational policies does not require rewriting business features.

Business Logic

↓

Shared Platform Services

↓

Provider Adapters

↓

External Providers

This separation should remain the preferred architectural direction wherever justified by product value and maintenance cost.

⸻

FINAL OWNER NOTE

This document exists solely to ensure that important platform, architecture, production, operational and provider-related ideas are never forgotten during Akshara’s long development journey.

It is intentionally separate from the execution roadmap.

This document is an Owner Reminder Queue, not an Execution Queue.

Implementation authority always remains:

Current Code

↓

Evidence

↓

Architecture Audit

↓

PRC Reconciliation

↓

Roadmap Reconciliation

↓

Owner Approval

↓

Implementation

No feature, architecture change, provider integration, abstraction, or platform enhancement should enter development directly from this document.

Only verified, genuinely missing, non-duplicate work may become part of the canonical roadmap.

⸻

END OF DOCUMENT