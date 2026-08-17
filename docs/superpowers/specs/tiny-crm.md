# Tiny CRM — Specification

## Purpose

A functional, small-scale CRM application built within a single day to demonstrate proficiency in legacy .NET web development (ASP.NET MVC 5 on .NET Framework 4.7) and modern AI-assisted coding workflows (OpenCode terminal + cloud Ollama model).

## Scope

In scope:
- User authentication (login/logout, session-based)
- Dashboard (session-based metrics, recent activities, quick links)
- Customer CRUD (Name, Email, Phone, Company, Status)
- Interaction tracking (log notes per customer, history list)
- Basic reporting (customer count grouped by status)
- Session handling with predefined timeout (20 minutes)

Out of scope:
- Search/filter on customer list (YAGNI for one-day build)
- Separate app-level audit logging (Interaction history covers recent activities)
- Role-management UI (single seeded admin role, no admin panel)
- Publish/deployment pipeline (in-place dev on IIS)
- Mobile-responsive bespoke design (Bootstrap 4 default suffices)

## Original Request

> Developer Assignment Specification: Tiny CRM Objective: Build a functional, small-scale CRM application within a single day to demonstrate proficiency in legacy .NET web development and modern AI-assisted coding workflows. Technology Stack Framework: .NET Framework 4.7 Architecture: ASP.NET MVC with Razor views State Management: Heavy reliance on server-side sessions AI Tools: OpenCode terminal integrated with a cloud Ollama model Core Features Required User Authentication: A simple login screen that initializes the user session. Dashboard: A main landing page displaying session-based user metrics, recent activities, and quick access links. Customer Management: Complete CRUD operations for managing customer records. Fields required: Name, Email, Phone, Company, and Status (e.g., Lead, Contact, Customer). Interaction Tracking: Ability to log notes or interactions against each customer profile. List view showing the history of interactions for a selected customer. Basic Reporting: A simple view displaying the count of customers grouped by their status. Session Handling: Implementation of a session state management strategy to maintain user state across requests, with a predefined timeout. Development Guidelines The application must be developed utilizing the OpenCode terminal paired with a cloud Ollama model for code assistance and generation. The final submission should include the source code and a brief overview of how the AI tools were leveraged during the build process.

## Grilling Record

See `docs/superpowers/specs/2026-08-12-tiny-crm-design.md` → `## Grilling Record` for the full settled-question log (24 questions across 3 rounds). All decisions carried forward into this specification.

## Requirements

### R1 — User Authentication
- The app shall provide a login screen at `/Account/Login`.
- Login accepts username + password, validated against a `Users` table in SQL Express.
- Passwords stored as BCrypt hashes (BCrypt.Net-Next).
- On success: store `UserId`, `Username`, `Role` in server-side Session; redirect to `ReturnUrl` query param or `/Dashboard`.
- On failure: re-render login with validation summary.
- Login form includes `@Html.AntForgeryToken()` (CSRF protection).
- Logout (`GET /Account/Logout`) abandons the session and redirects to login.
- Seeded demo user: `admin` / `Admin@123`, role `Admin`.

### R2 — Session Handling
- Session mode: `InProc`, timeout 20 minutes (set in `web.config` `<sessionState>`).
- A custom `[SessionAuthAttribute]` MVC filter enforces authentication on protected controllers. If Session lacks `UserId`, redirect to `/Account/Login?ReturnUrl=<requested>`.
- Session is used for auth/identity state only. Customer/interaction data persists in SQL Express (not session), surviving session expiry.

### R3 — Dashboard
- `GET /Dashboard` (protected by `[SessionAuth]`).
- Displays: total customer count, customers grouped by status (counts), 5 most recent interactions across all customers (with customer name + type + timestamp), and quick-access links to Create Customer / Reports / Logout.

### R4 — Customer Management (CRUD)
- `Customers` table: Id, Name, Email, Phone, Company, Status, CreatedAt, UpdatedAt, CreatedByUserId.
- Status is a fixed set: Lead, Contact, Customer (enforced by SQL CHECK constraint + C# enum).
- `GET /Customers` — paginated list (10/page via Skip/Take), shows Name/Email/Phone/Company/Status with Details/Edit/Delete action links.
- `GET /Customers/Create` — form with Name/Email/Phone/Company/Status dropdown.
- `POST /Customers/Create` — DataAnnotations validation, insert with `CreatedByUserId` from session, redirect to list.
- `GET /Customers/Edit/{id}` — pre-filled form.
- `POST /Customers/Edit/{id}` — update, set `UpdatedAt`.
- `GET /Customers/Details/{id}` — customer info + interaction history.
- `POST /Customers/Delete/{id}` — deletes customer; interactions cascade-deleted via SQL FK.
- Validation: DataAnnotations (`[Required]`, `[EmailAddress]`, `[StringLength]`) + jQuery validate unobtrusive (client-side).

### R5 — Interaction Tracking
- `Interactions` table: Id, CustomerId (FK CASCADE), Type, Note, LoggedAt, LoggedByUserId (FK to Users).
- Type is a fixed set: Call, Email, Meeting, Note (SQL CHECK + C# enum).
- `POST /Interactions/Create/{customerId}` — logs note + type + timestamp + `LoggedByUserId` from session, redirects to `/Customers/Details/{customerId}`.
- Interactions listed within Customer Details view (per spec: "List view showing the history of interactions for a selected customer").

### R6 — Basic Reporting
- `GET /Reports` (protected).
- Queries `SELECT Status, COUNT(*) FROM Customers GROUP BY Status`.
- Renders a table (Status | Count) with Bootstrap horizontal progress bars (width % = count/total*100).

### R7 — Data Storage
- SQL Express instance `.\SQLEXPRESS` on the Windows Server 2025 guest VM.
- Database name: `ShopCRM`.
- Schema created via `sql/schema.sql` (DDL + seed data), run once via WinRM.
- Connection string in `web.config` `<connectionStrings>`: `Server=.\SQLEXPRESS;Database=ShopCRM;Integrated Security=True;`.
- Data access: ADO.NET (`SqlConnection`/`SqlCommand`) with parameterized SQL in a repository layer. No Entity Framework.

### R8 — UI & Styling
- Bootstrap 4 via CDN.
- Shared `_Layout.cshtml`: navbar with "Tiny CRM" branding, conditional links (Dashboard/Customers/Reports/Logout) shown only when logged in.
- Login page uses bare layout (no navbar).
- Custom `Shared/Error.cshtml` with `customErrors mode="On"` — friendly message, no stack traces.

### R9 — Project Structure
- Single ASP.NET MVC 5 project at `C:\src\Shop` on the guest.
- Folders: `Controllers/`, `Models/`, `Repository/`, `Infrastructure/`, `Views/`, `sql/`.
- `packages.config` with BCrypt.Net-Next (nuget restore on guest; DLL-copy fallback if no internet).

### R10 — Deployment
- In-place dev: IIS site `Shop` (application under Default Web Site) points at `C:\src\Shop`.
- App pool: .NET CLR v4.0, Integrated pipeline, identity `LocalSystem` (Windows auth to SQL Express).
- URL: `http://localhost/Shop`.
- Git workflow: bare repo at `/home/krylor/dev/yash/Shop.git` on host → guest `git pull` to `C:\src\Shop`.

## Exclusions
- No search/filter on customer list.
- No app-level audit log beyond Interactions.
- No role-management UI.
- No publish/profile-based deployment.
- No EF/migrations.
- No split-layer architecture (single project).

## Interfaces
- **External**: HTTP browser at `http://localhost/Shop` (guest).
- **Internal**: ADO.NET → SQL Express `ShopCRM` via Windows auth.
- **Repository interfaces**: `IUserRepository`, `ICustomerRepository`, `IInteractionRepository` (consumed by controllers, implemented by ADO.NET repos).
- **Auth filter**: `SessionAuthAttribute : ActionFilterAttribute` — reads Session, redirects on missing `UserId`.

## Failure Behavior
- Session expired → `[SessionAuth]` redirects to login with `ReturnUrl`.
- DB unreachable → unhandled exception → custom `Error.cshtml` (friendly message, stack trace hidden).
- Invalid CRUD input → DataAnnotations ModelState invalid → re-render form with validation messages.
- Customer not found on Edit/Details/Delete → return 404 (HttpNotFound).
- BCrypt NuGet unavailable on guest → fallback to DLL copy via WinRM; final escape hatch: SHA256+per-user-salt.

## Security Constraints
- All passwords BCrypt-hashed; no plaintext storage.
- All SQL parameterized (no string concatenation) — prevents SQL injection.
- `@Html.AntForgeryToken()` on login POST (CSRF).
- `customErrors mode="On"` in production (stack traces hidden).
- Session timeout enforces re-auth after 20 min idle.
- App pool identity `LocalSystem` for Windows-auth to SQL Express.

## Acceptance Criteria
1. User can log in with `admin`/`Admin@123` and is redirected to Dashboard.
2. Dashboard shows total customers, status counts, and 5 recent interactions.
3. User can create, read, update, and delete customers with all required fields.
4. User can log interactions (Call/Email/Meeting/Note) against a customer and see them listed in the customer's Details view.
5. Reports view shows customer counts grouped by status with visual bars.
6. After 20 min idle, next request redirects to login; customer data survives in SQL.
7. App runs at `http://localhost/Shop` on the guest VM, served by IIS.
8. Source code in git; write-up documents how OpenCode + cloud Ollama were used.