# Database Relationships
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Foreign Key Relationships

```mermaid
erDiagram
    users ||--o{ members : "has many"
    users ||--o{ messages : "writes"
    users ||--o{ servers : "owns"
    servers ||--o{ channels : "contains"
    servers ||--o{ members : "has"
    servers ||--o{ roles : "defines"
    channels ||--o{ messages : "contains"
    channels ||--o{ channels : "parent_id"
    roles ||--o{ member_roles : "assigned to"
    users ||--o{ member_roles : "has"
    servers ||--o{ invites : "has"
    users ||--o{ invites : "creates"
    servers ||--o{ bots : "installed"
```

## Cascade Rules
| Relationship | On Delete |
|-------------|-----------|
| servers → users (owner) | RESTRICT (can't delete user who owns servers) |
| channels → servers | CASCADE |
| messages → channels | CASCADE |
| members → servers | CASCADE |
| members → users | CASCADE |
| roles → servers | CASCADE |
| invites → servers | CASCADE |
| bot_guilds → servers | CASCADE |
| All bot settings → servers | CASCADE |
