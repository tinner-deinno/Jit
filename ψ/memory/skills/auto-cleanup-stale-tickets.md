---
name: auto-cleanup-stale-tickets
description: Detect and notify on stale tickets
---
# SOP: Auto-Cleanup Stale Tickets

## 1. Detection Criteria
Identify tickets where `status` is "in-progress" for >7 days without meaningful updates.

### Detection Rules
1. **Regex Rule**: Match status field pattern: `/status\s*[:=]\s*["']?in-progress["']?/i`
2. **Time-Based Rule**: `Date.now() - new Date(ticket.last_updated).getTime() > 7 * 24 * 60 * 60 * 1000`
3. **Assignee-Based Rule**: `ticket.assignee.last_activity <= ticket.last_updated` (Assignee has not logged activity since the ticket entered in-progress).

## 2. Auto-Actions
When ALL 3 rules evaluate to TRUE, execute sequentially:
- **Notify**: Send automated system message/email to `ticket.assignee.email`: "Alert: Ticket #{id} has been in-progress for >7 days. Please update or it will be closed."
- **Mark**: Update ticket metadata: `ticket.tags.push('stale-review')` and set `ticket.status = 'stale'`.

## 3. Test Cases

### Test Case 1: Stale Ticket (Triggers Action)
```json
{
  "id": "TCK-884",
  "status": "in-progress",
  "last_updated": "2023-10-01T10:00:00Z",
  "assignee": {
    "email": "dev@example.com",
    "last_activity": "2023-10-01T10:00:00Z"
  }
}
// Current Date: 2023-10-10
// Expected: Regex matches, Time > 7 days, Assignee inactive. 
// Result: Notify assignee, mark status 'stale'.
```

### Test Case 2: Active Ticket (No Action)
```json
{
  "id": "TCK-885",
  "status": "in-progress",
  "last_updated": "2023-10-08T10:00:00Z",
  "assignee": {
    "email": "dev@example.com",
    "last_activity": "2023-10-09T14:00:00Z"
  }
}
// Current Date: 2023-10-10
// Expected: Time < 7 days, Assignee active. 
// Result: No action taken.
```

