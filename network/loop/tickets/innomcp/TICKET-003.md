# TICKET-003: Thai GeoTool Verification
**Team**: innomcp
**Status**: pending
**Owner**: Jit (จิต) — Mother Orchestrator
**Priority**: P1
**Cycle assigned**: 176

## Goal
Verify that the Thai GeoTool (geocoding/places lookup for Thai addresses, districts, provinces) returns correct results. If a `limbs/thai-geo.js` or similar exists, exercise it. If not, document the gap.

## Steps
1. Grep for `geo` / `geocode` / `province` / `amphoe` / `tambon` in `limbs/`, `organs/`, `core/`.
2. If found, run unit tests with 5 known queries: "กรุงเทพมหานคร", "เชียงใหม่", "ภูเก็ต", "เมืองขอนแก่น", "อำเภอเมืองเชียงใมาก".
3. If not found, write a stub `limbs/thai-geo.js` that returns province/amphoe/tambon/zipcode for any input, backed by a small in-memory dataset.
4. Run a fleet of 10 workers querying the GeoTool through thaillm to verify end-to-end.

## Acceptance
- A `limbs/thai-geo.js` (or equivalent) exists and passes 5/5 known queries.
- Fleet cycle with Thai geo queries returns useful answers in >= 70% of cases.

## Confidence: 60
