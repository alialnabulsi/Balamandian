# Tools implementation status

The branch contains the six Tools destinations, account access gates, shared-shell
navigation, private persistence and the requested compact UI refinements. The feature implementation remains on feature/tools. The architectural correction
preserves the existing UI and application database persistence.

| Feature | Current behavior |
| --- | --- |
| To-do | Owner CRUD, List/Kanban on one collection, progress, long-press dragging/edge scroll/status menu, confirmed server status, centered action labels |
| GPA | Compact numeric calculator, manual baseline, authenticated SIS-API grade import into private profile cache; derived values labelled accurately |
| My Notes | Private folders, text/formatting/drawings/files, local recovery/autosave, directly writable new note, Save returns to browser |
| Lost & Found | Blue/yellow/green entry choices, private reports/files, My reports, withdrawal/history, durable pending OSA events |
| Calendar | Official academic dates, protected university/personal events, category filters, distinct month surface, simple editor and native Android reminders |
| Schedule | SIS plan/sections/enrollment via authenticated SIS-API HTTP, app-side registration configuration, conflict-free alternatives, selected proposal and actual read-only timetable |

SIS-API remains unchanged. Flutter calls Balamandian-API only; institutional data
must pass through authenticated SIS-API endpoints. Direct SIS database access is
prohibited and the former read-only adapter was removed. Missing academic HTTP
contracts are coordinated with Ali in SIS-API issue 1; until implemented, imports
report unavailability while retaining existing application caches and manual GPA.

The [historical branch audit](feature-tools-audit.md) records earlier recovery
verification; its former direct database exception is superseded by the HTTP contract.
Backend contracts: [academics](../../Balamandian-API/docs/academics.md),
[scheduler](../../Balamandian-API/docs/scheduler.md),
[calendar](../../Balamandian-API/docs/calendar.md),
[lost & found](../../Balamandian-API/docs/lost-found.md),
[notes](../../Balamandian-API/docs/notes.md), [tasks](../../Balamandian-API/docs/tasks.md).

OSA delivery remains pending without a configured recipient/worker; no real
university personnel were messaged. Native alarms use Android's inexact delivery
and require physical-device permission/background/reboot checks. Remote server
changes reconcile on the next app sync; no push provider was added.
