# Tiny CRM — Design

## Original Request

> Developer Assignment Specification: Tiny CRM Objective: Build a functional, small-scale CRM application within a single day to demonstrate proficiency in legacy .NET web development and modern AI-assisted coding workflows. Technology Stack Framework: .NET Framework 4.7 Architecture: ASP.NET MVC with Razor views State Management: Heavy reliance on server-side sessions AI Tools: OpenCode terminal integrated with a cloud Ollama model Core Features Required User Authentication: A simple login screen that initializes the user session. Dashboard: A main landing page displaying session-based user metrics, recent activities, and quick access links. Customer Management: Complete CRUD operations for managing customer records. Fields required: Name, Email, Phone, Company, and Status (e.g., Lead, Contact, Customer). Interaction Tracking: Ability to log notes or interactions against each customer profile. List view showing the history of interactions for a selected customer. Basic Reporting: A simple view displaying the count of customers grouped by their status. Session Handling: Implementation of a session state management strategy to maintain user state across requests, with a predefined timeout. Development Guidelines The application must be developed utilizing the OpenCode terminal paired with a cloud Ollama model for code assistance and generation. The final submission should include the source code and a brief overview of how the AI tools were leveraged during the build process.

Context: One-day build of a legacy .NET MVC CRM demo, running on the `win-iis-dev` Windows Server 2025 VM (IIS + SQL Express), edited from a Pop!_OS host via WinRM, source kept in git and pulled onto the guest.

## Grilling Record

### Round 1

| Q | Question | Settled Answer | Decision |
|---|----------|----------------|----------|
| Q1 | Password hashing | BCrypt.Net-Next | Use BCrypt.Net-Next NuGet; DLL fallback if guest isolated |
| Q2 | Customer Name field | Single `Name` string | Matches spec literally; no FirstName/LastName split |
| Q3 | Status values | VARCHAR + enum, fixed set | CHECK constraint in SQL, enum in C# |
| Q4 | Interaction fields | Note + timestamp + Type + LoggedByUserId | Type enum: Call/Email/Meeting/Note; FK to Users |
| Q5 | Connection string | web.config `<connectionStrings>` | .NET 4.7 standard location |
| Q6 | Session contents | UserId + Username + Role | Dashboard greets by name; Role for future admin features |
| Q7 | Auth enforcement | Custom `[SessionAuth]` attribute | Cleaner than ASP.NET membership/Identity plumbing |
| Q8 | Dashboard metrics | Total customers, by-status counts, 5 recent interactions, quick links | Covers spec; no scope creep |
| Q9 | Report view | Table + Bootstrap horizontal bars | Polished, zero extra libs |
| Q10 | Seed data | 1 demo user + ~10 customers + interactions | Demo looks alive |
| Q11 | Validation | DataAnnotations + jQuery unobtrusive | Ships with MVC 5 template; free |
| Q12 | Project structure | Single project, folder-based | One-day build; layered arch adds ceremony for no payoff |
| Q13 | DB initialization | SQL script run once via WinRM, at `/sql/schema.sql` | Explicit, inspectable; app just connects |

### Round 2

| Q | Question | Settled Answer | Decision |
|---|----------|----------------|----------|
| Q14 | NuGet on guest | `nuget restore` first, DLL copy fallback, SHA256+salt escape hatch | Try public gallery; isolate-aware fallback chain |
| Q15 | Delete behavior | CASCADE delete interactions when customer deleted | No orphans; simplest |
| Q16 | Roles | Single `Role` column on Users, seeded admin = "Admin" | Gives session Role a purpose; no role-management UI |
| Q17 | Login redirect & anti-forgery | ReturnUrl redirect + `@Html.AntForgeryToken()` | Standard + CSRF-safe |
| Q18 | Demo credentials | `admin` / `Admin@123` | BCrypt-hashed at seed time |
| Q19 | DB details | `.\SQLEXPRESS`, DB `ShopCRM`, script at `/sql/schema.sql` | Windows auth in conn string; verify instance name on guest via WinRM |

### Round 3

| Q | Question | Settled Answer | Decision |
|---|----------|----------------|----------|
| Q20 | Error handling | Custom `Error.cshtml`, `customErrors mode="On"` | Hides stack traces; professional |
| Q21 | Pagination | 10/page via Skip/Take | Correct pattern; trivial now vs retrofit later |
| Q22 | Search/filter | Skip (YAGNI) | Spec lists no search; add at end if time permits |
| Q23 | Logging | Skip | Interaction history covers "recent activities" |
| Q24 | Deployment | In-place dev; IIS site → `C:\src\Shop` | No publish step; matches BUILD-PLAN |

## Architecture & Project Structure

**Single ASP.NET MVC 5 project on .NET Framework 4.7.**

```
Shop/
├── Controllers/
│   ├── AccountController.cs        # login/logout
│   ├── DashboardController.cs      # landing page
│   ├── CustomersController.cs      # CRUD
│   ├── InteractionsController.cs   # log/list interactions
│   └── ReportsController.cs        # status counts
├── Models/
│   ├── User.cs, Customer.cs, Interaction.cs
│   └── LoginViewModel.cs, CustomerViewModel.cs, InteractionViewModel.cs
├── Repository/
│   ├── IUserRepository.cs / UserRepository.cs
│   ├── ICustomerRepository.cs / CustomerRepository.cs
│   └── IInteractionRepository.cs / InteractionRepository.cs
├── Infrastructure/
│   ├── SessionAuthAttribute.cs      # [SessionAuth] filter
│   └── DbConnectionFactory.cs       # reads web.config conn string
├── Views/
│   ├── Account/Login.cshtml
│   ├── Dashboard/Index.cshtml
│   ├── Customers/{Index,Create,Edit,Details}.cshtml
│   ├── Interactions/ (partial for inline logging)
│   ├── Reports/Index.cshtml
│   └── Shared/{_Layout,_LoginLayout,Error}.cshtml
├── sql/
│   └── schema.sql                   # DDL + seed data
├── web.config                       # conn string, session timeout, customErrors
├── packages.config                  # BCrypt.Net-Next
└── Shop.csproj
```

**Data flow:** Browser → Controller → `[SessionAuth]` filter → Repository (ADO.NET, parameterized SQL) → SQL Express `ShopCRM` → Razor view renders result. Session holds `UserId/Username/Role`, enforced by the custom attribute. No EF, no membership/Identity plumbing.

## Data Model

Three tables in `ShopCRM`:

### Users
| Column | Type | Notes |
|--------|------|-------|
| Id | INT IDENTITY PK | |
| Username | NVARCHAR(50) UNIQUE NOT NULL | |
| PasswordHash | NVARCHAR(255) NOT NULL | BCrypt hash |
| Role | NVARCHAR(20) NOT NULL | 'Admin' or 'User' |
| CreatedAt | DATETIME2 DEFAULT SYSUTCDATETIME | |

### Customers
| Column | Type | Notes |
|--------|------|-------|
| Id | INT IDENTITY PK | |
| Name | NVARCHAR(100) NOT NULL | single string |
| Email | NVARCHAR(100) | |
| Phone | NVARCHAR(30) | |
| Company | NVARCHAR(100) | |
| Status | NVARCHAR(20) NOT NULL CHECK IN ('Lead','Contact','Customer') | enum constraint |
| CreatedAt | DATETIME2 DEFAULT SYSUTCDATETIME | |
| UpdatedAt | DATETIME2 NULL | set on every edit |
| CreatedByUserId | INT FK → Users.Id | |

### Interactions
| Column | Type | Notes |
|--------|------|-------|
| Id | INT IDENTITY PK | |
| CustomerId | INT FK → Customers.Id ON DELETE CASCADE | |
| Type | NVARCHAR(20) NOT NULL CHECK IN ('Call','Email','Meeting','Note') | |
| Note | NVARCHAR(MAX) NOT NULL | |
| LoggedAt | DATETIME2 DEFAULT SYSUTCDATETIME | |
| LoggedByUserId | INT FK → Users.Id | from session |

**Relationships:**
- Customer 1:N Interactions (cascade delete)
- User 1:N Customers (created by)
- User 1:N Interactions (logged by)

**Seed data** (in `schema.sql`):
- 1 user: `admin` / `Admin@123` (BCrypt hash), role `Admin`
- ~10 customers (mix of Lead/Contact/Customer statuses)
- ~3-5 interactions spread across customers

## Application Flow & Controllers

Route convention: `{controller}/{action}/{id?}` (MVC default). All protected controllers carry `[SessionAuth]`.

### AccountController (no auth)
- `GET /Account/Login` — renders login form with `ReturnUrl` query + `@Html.AntForgeryToken()`
- `POST /Account/Login` — validates against DB via `UserRepository`, BCrypt-verify, stores `UserId/Username/Role` in Session, redirects to `ReturnUrl` or `/Dashboard`
- `GET /Account/Logout` — `Session.Abandon()`, redirect to Login

### DashboardController `[SessionAuth]`
- `GET /Dashboard` — pulls: total customers, customers-by-status counts, 5 most recent interactions (joined with customer name), renders Dashboard view with quick-access links

### CustomersController `[SessionAuth]`
- `GET /Customers` — paginated list (10/page via Skip/Take on query), shows Name/Email/Phone/Company/Status
- `GET /Customers/Create` — empty form
- `POST /Customers/Create` — DataAnnotations validation, repo insert with `CreatedByUserId` from session
- `GET /Customers/Edit/{id}` — pre-filled form
- `POST /Customers/Edit/{id}` — update, set `UpdatedAt`
- `GET /Customers/Details/{id}` — customer info + their interaction history (calls InteractionRepository)
- `POST /Customers/Delete/{id}` — cascade handled by SQL FK, redirect to list

### InteractionsController `[SessionAuth]`
- `POST /Interactions/Create/{customerId}` — log note + type + timestamp + `LoggedByUserId` from session, redirect back to `/Customers/Details/{customerId}`
- Interactions listed within Customer Details (per spec: "List view showing the history of interactions for a selected customer")

### ReportsController `[SessionAuth]`
- `GET /Reports` — `SELECT Status, COUNT(*) FROM Customers GROUP BY Status`, renders table + Bootstrap horizontal bars (width % = count/total*100)

### Session timeout behavior
When session expires (20 min idle), next request hits `[SessionAuth]`, finds no UserId in session, redirects to `/Account/Login?ReturnUrl=...`. User data is safe in SQL — only login state lost.

## Views & Styling

**Shared layout** (`_Layout.cshtml`): Bootstrap 4 via CDN, navbar with app name "Tiny CRM", conditional links (Dashboard / Customers / Reports / Logout) shown only when logged in, `@RenderBody()` main area, footer. Login page uses a bare layout (no navbar).

**Views:**
- `Account/Login.cshtml` — centered card, username/password fields, anti-forgery, validation summary
- `Dashboard/Index.cshtml` — 3 stat cards (total / by-status mini table / recent interactions list) + quick-access buttons
- `Customers/Index.cshtml` — table with pager (Bootstrap pagination), action links (Details/Edit/Delete)
- `Customers/Create.cshtml` + `Edit.cshtml` — form with Name/Email/Phone/Company/Status dropdown, jQuery unobtrusive validation
- `Customers/Details.cshtml` — customer info card + interactions list (Type badge, Note, LoggedAt, LoggedBy) + "Log interaction" inline form
- `Reports/Index.cshtml` — status table with horizontal Bootstrap progress bars
- `Shared/Error.cshtml` — friendly error message, hides stack trace

**Validation:** DataAnnotations on view models (`[Required]`, `[EmailAddress]`, `[StringLength]`) + jQuery validate unobtrusive (ships with MVC 5 template) for client-side.

## Infrastructure & Deployment

**Git workflow:**
- Bare repo on host: sibling `Shop.git` at `/home/krylor/dev/yash/Shop.git` → guest clones/pulls to `C:\src\Shop` (keeps the working dir `legacy-CRM-app` separate from the bare repo)
- Commit flow: edits on host → push to bare repo → WinRM runs `git pull` on guest at `C:\src\Shop`

**DB setup (one-time via WinRM):**
1. Verify SQL Express instance name on guest (`Get-Service *SQL*` via WinRM)
2. Run `sql/schema.sql` against `.\SQLEXPRESS` to create `ShopCRM` DB + tables + seed data
3. Confirm `admin` / `Admin@123` row exists with valid BCrypt hash

**IIS setup (one-time via WinRM):**
1. Create site `Shop` pointing at `C:\src\Shop`
2. App pool: .NET CLR v4.0, Integrated pipeline, identity = `LocalSystem` (Windows auth to SQL Express)
3. Bind: `http://localhost/Shop` as an application under the Default Web Site
4. Ensure HTTP handlers for Razor are registered

**web.config key sections:**
- `<connectionStrings>`: `Server=.\SQLEXPRESS;Database=ShopCRM;Integrated Security=True;`
- `<sessionState mode="InProc" timeout="20" />`
- `<customErrors mode="On" />`
- `<authentication mode="None" />` (custom session-based auth, not ASP.NET membership)

**Build/verify loop:**
- Edit on host → commit → `git push` → WinRM `git pull` on guest → browse `http://localhost/Shop` in guest browser

**NuGet (BCrypt.Net-Next):**
- `packages.config` + `nuget restore` on guest first; if no outbound internet, download BCrypt.Net DLL on host, copy via WinRM to `C:\src\Shop\bin`