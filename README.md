# Tiny CRM

A small CRM built on **.NET Framework 4.7**, **ASP.NET MVC 5**, **Razor views**, and **IIS** on the `WIN-IIS-DEV` Windows Server VM. SQL Express holds `ShopCRM`.

This repo is the **legacy** stack only. The Vue / .NET 10 edition lives in [tiny-crm-net10-vue](https://github.com/chatgptkrylor/tiny-crm-net10-vue).

## Stack

| Layer | Tech |
|---|---|
| UI | Razor views, Bootstrap 4 |
| App | .NET Framework 4.7, ASP.NET MVC 5 |
| Auth | Server-side sessions, BCrypt, 20-minute timeout |
| Data | SQL Server Express (`ShopCRM`) on WIN-IIS-DEV |
| Host | IIS, app pool `ShopAppPool`, site `/Shop` |

## Run it

On the Linux host that runs the VM:

```bash
./scripts/start-shop.sh
```

That starts WIN-IIS-DEV, SQL Express, IIS, and a proxy on port **5174**.

- Local: http://localhost:5174
- Tailscale: `http://<this-host>.tail2e3aa.ts.net:5174`

Login: `admin` / `Admin@123`

## Layout

```
src/backend/     C# MVC (controllers, repositories, ADO.NET)
src/frontend/    Razor views
scripts/         start-shop.sh, VM/SQL helpers
tests/           PowerShell verify scripts
```

## Demo

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `Admin@123` |
