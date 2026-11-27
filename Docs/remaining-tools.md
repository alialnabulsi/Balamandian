# Tools implementation status

The branch contains the six Tools destinations, account access gates, shared-shell
navigation, private persistence and the requested compact UI refinements. Earlier
work remains uncommitted; the original 20 staged frontend files were preserved.

| Feature | Current behavior |
| --- | --- |
| To-do | Owner CRUD, List/Kanban on one collection, progress, long-press dragging/edge scroll/status menu, confirmed server status, centered action labels |
| GPA | Compact numeric calculator, manual baseline, read-only SIS grade import into private profile cache; derived values labelled accurately |
| My Notes | Private folders, text/formatting/drawings/files, local recovery/autosave, directly writable new note, Save returns to browser |
| Lost & Found | Blue/yellow/green entry choices, private reports/files, My reports, withdrawal/history, durable pending OSA events |
| Calendar | Official academic dates, protected university/personal events, category filters, distinct month surface, simple editor and native Android reminders |
| Schedule | Original SIS plan/sections/enrollment via read-only adapter, app-side registration configuration, conflict-free alternatives, selected proposal and actual read-only timetable |

SIS-API has been restored to its original clean files and 25-table local schema.
All original table row counts were preserved. Its API still exposes authentication
and member retrieval only. The user explicitly approved a read-only academic DB
adapter in Balamandian-API; Flutter continues to call its own backend only.
No SIS academic migration, new publication/registration table or invented API
contract is required. App migration 0009 remains unchanged because it was applied
and its private cache/date/sync fields are reused.

See the [full branch audit](feature-tools-audit.md) for the final inventory,
validation, source-capability matrix, open constraints and release checks.
Backend contracts: [academics](../../Balamandian-API/docs/academics.md),
[scheduler](../../Balamandian-API/docs/scheduler.md),
[calendar](../../Balamandian-API/docs/calendar.md),
[lost & found](../../Balamandian-API/docs/lost-found.md),
[notes](../../Balamandian-API/docs/notes.md), [tasks](../../Balamandian-API/docs/tasks.md).

OSA delivery remains pending without a configured recipient/worker; no real
university personnel were messaged. Native alarms use Android's inexact delivery
and require physical-device permission/background/reboot checks. Remote server
changes reconcile on the next app sync; no push provider was added.
