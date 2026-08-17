# AI Tools Usage — Tiny CRM Build

This document summarizes how OpenCode (terminal) paired with a cloud Ollama model was leveraged to build the Tiny CRM application.

## Toolchain

- **OpenCode** — interactive terminal agent used for all coding, orchestration, and VM automation.
- **Cloud Ollama model** — the LLM backend powering code generation, debugging, and planning.
- **Superpowers X lifecycle** — brainstorming → spec → tickets → orchestrator → ticket execution → board review.

## How AI was used

### 1. Design & planning
- Brainstormed requirements from the assignment spec into a full design (architecture, data model, auth, session strategy).
- Grilled the design across 3 rounds (24 settled decisions) before writing the spec.
- Decomposed the spec into 9 vertical-slice tickets (T01–T09) with ownership and verification commands.

### 2. Code generation
- Generated all C# models, repositories (ADO.NET), controllers, and Razor views.
- Generated the SQL schema + seed data script.
- Generated the build/deploy PowerShell script (`build-csc.ps1`).

### 3. VM automation
- Drove the Windows Server 2025 guest (IIS + SQL Express) headlessly via SSH/PowerShell from the Linux host.
- Automated build → deploy → IIS app-pool restart → HTTP verification loops.

### 4. Debugging
- Used systematic debugging to isolate failures:
  - App-pool SQL login denied → granted `db_datareader`/`db_datawriter` to `IIS APPPOOL\ShopAppPool`.
  - BCrypt.Net-Next 4.0.3 missing `System.Memory` → downgraded to 3.3.0 (net472, no transitive deps).
  - Auth redirect 404 → made `[SessionAuth]` redirect application-aware (`/Shop/Account/Login`).
  - Razor parse error → simplified the login view.

### 5. Verification
- Automated end-to-end smoke tests via PowerShell: login, dashboard, customer CRUD, interaction logging, reports.
- Verified all pages return 200 and render expected content.

## Outcome

A functional Tiny CRM running at `http://localhost/Shop` on the `win-iis-dev` VM:
- Login (BCrypt-hashed users, session-based, 20-min timeout)
- Dashboard (metrics, recent interactions, quick links)
- Customer CRUD (Name/Email/Phone/Company/Status)
- Interaction tracking (Call/Email/Meeting/Note)
- Reports (customers grouped by status with bars)
- SQL Express `ShopCRM` database with seeded demo data