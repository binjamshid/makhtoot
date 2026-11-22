# Sync Manual Test Script — MakhtootKit / MKSync

WS-11 deliverable (T16). This document covers two-device CloudKit sync test
procedures T-sync-01 through T-sync-06.

**Environment requirement:** Two physical iOS devices (or one physical device
+ one Simulator), both signed in to the **same** iCloud account, with MKSync
enabled (Premium subscription active). iCloud Drive must be enabled in
Settings → [your name] → iCloud → iCloud Drive.

**Status:** All six tests are **environment-deferred** — they require live
CloudKit and cannot be executed in the CI environment (no entitlement, no
real iCloud account). Mark PASS/FAIL manually after each physical-device
test run.

---

## Test environment setup

1. Install a Debug build of Makhtoot on both devices from the same source.
2. Sign both devices into the same iCloud account.
3. Open Makhtoot on both devices.
4. Subscribe to Premium on Device A (or use a StoreKit test account with
   `.cloudSync` capability granted).
5. Enable "Sync with iCloud" in Settings on both devices.
6. Wait ~30 seconds for the initial zone creation to complete. You should
   see the sync status indicator settle to "تم المزامنة" (idle).

---

## T-sync-01 — Basic upload and download

**Purpose:** Verify that a project created on Device A appears on Device B.

**Steps:**

1. On Device A, create a new project titled "اختبار المزامنة".
2. Add some text elements to the canvas.
3. Wait for the sync status badge to change from "جارٍ الرفع" to "تم المزامنة"
   (approximately 10–30 seconds depending on network).
4. On Device B, pull to refresh the project list (or wait for the automatic
   push notification to trigger a fetch).
5. Verify that "اختبار المزامنة" appears in the project list on Device B.
6. Open the project on Device B and confirm the canvas content matches.

**Expected result:** Project appears on Device B with identical content.

**Pass / Fail:** ___________

---

## T-sync-02 — Edit on one device syncs to the other

**Purpose:** Verify that edits on Device A propagate to Device B.

**Pre-condition:** T-sync-01 passed; "اختبار المزامنة" exists on both devices.

**Steps:**

1. On Device A, open "اختبار المزامنة" and modify the canvas (e.g. change
   a text element's colour, add a new shape).
2. Close/background the project on Device A.
3. Wait for sync badge to show "تم المزامنة".
4. On Device B, open "اختبار المزامنة".
5. Verify the change is reflected.

**Expected result:** Edit propagated; Device B shows updated content.

**Pass / Fail:** ___________

---

## T-sync-03 — Conflict copy creation

**Purpose:** Verify that simultaneous edits on both devices produce a conflict
copy with the correct Arabic name.

**Steps:**

1. Put both devices in Airplane Mode.
2. On Device A, open "اختبار المزامنة" and make a distinct edit (e.g. add
   a red circle).
3. On Device B, open the same project and make a different edit (e.g. add a
   blue square). Make sure both edits result in a different `contentHash`
   (i.e. they genuinely diverge from the last-synced baseline).
4. Restore network on both devices simultaneously (or within a few seconds).
5. Wait for sync to complete on both devices.
6. Check the project list on both devices.

**Expected result:**
- The original "اختبار المزامنة" project reflects one device's version.
- A conflict copy named "اختبار المزامنة (نسخة متعارضة)" appears in the
  same folder.
- If a second conflict occurs (already one conflict copy), the next one is
  named "اختبار المزامنة (نسخة متعارضة ٢)".

**Pass / Fail:** ___________

---

## T-sync-04 — Delete on one device propagates to the other

**Purpose:** Verify that a deletion on Device A removes the project on Device B.

**Steps:**

1. On Device A, delete "اختبار المزامنة" (swipe-to-delete or long-press menu).
2. Wait for sync status to show "تم المزامنة".
3. On Device B, refresh the project list.
4. Verify "اختبار المزامنة" is no longer present.

**Expected result:** Project is removed from Device B's list.

**Pass / Fail:** ___________

---

## T-sync-05 — Delete-vs-edit resurrection (T6.d)

**Purpose:** Verify that editing a project on Device A while Device B deletes
it causes the edit to win (resurrection rule).

**Steps:**

1. Create a new project "اختبار الإحياء" on Device A and let it sync to
   Device B.
2. Put both devices in Airplane Mode.
3. On Device B, delete "اختبار الإحياء".
4. On Device A, open "اختبار الإحياء" and make a meaningful edit.
5. Restore network on both devices simultaneously.
6. Wait for sync to complete.

**Expected result:** "اختبار الإحياء" is present on both devices with Device
A's edit. Device A's version was re-uploaded as a new record because the user's
local edit happened after the remote deletion was issued (T6.d resurrection rule).

**Pass / Fail:** ___________

---

## T-sync-06 — Account switch isolation

**Purpose:** Verify that switching iCloud accounts on a device does not leak
data between accounts.

**Steps:**

1. Create at least two projects on Device A (Account 1). Confirm they are
   present on Device B (also Account 1).
2. On Device A, sign out of Account 1 in Settings → [your name] → Sign Out,
   then sign in as Account 2.
3. Relaunch Makhtoot on Device A.
4. Verify the project list on Device A is empty (or shows only projects that
   were already on Account 2, if any).
5. Verify that the sync status resets to "تم التعطيل" until Account 2's
   Premium entitlement is checked.
6. Sign back into Account 1 and verify Device A's projects from Account 1
   re-download cleanly.

**Expected result:** Account 2 cannot see Account 1's projects. Sync state
is fully isolated per iCloud account identity.

**Pass / Fail:** ___________

---

## Regression gate (automated)

Before any physical-device run, ensure:

```bash
swift test --package-path MakhtootKit --filter MKSyncTests
swift test --package-path MakhtootKit --filter MKPersistenceTests
bash Scripts/stub-source-audit.sh
```

All three must exit 0.
