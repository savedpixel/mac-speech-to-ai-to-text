# Insert Phrase OK Fix

<!-- Updated: 2026-05-19 -->

## Goal

Restore insert phrase insertion when the phrase is configured as `OK` / `ok`.

## Root Cause

The insert phrase variant builder handled `ok ...` and `okay ...` phrases, but did not add the exact single-word `okay` variant when the configured phrase was the single word `ok`. Apple's Speech framework commonly transcribes spoken `OK` as `okay`, so the listener could hear the user correctly but never match the configured trigger.

## Plan

1. Add exact `ok` ⇄ `okay` variants for insert phrase matching.
2. Normalize punctuation in recognized partial transcripts before matching.
3. Add diagnostic file log entries for insert listener start, transcript partials, trigger match, stop, and errors.
4. Bump app version/build, rebuild, sign, relaunch, and verify the listener starts from the completed state.
