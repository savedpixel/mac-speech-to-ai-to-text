# Media Resume Timing Fix

- Date: 2026-03-30
- Status: Complete

## Goal

Resume paused media as soon as recording ends and the pipeline enters transcription, instead of waiting until the result is copied or inserted.

## Checklist

- [ ] Confirm the current pause/resume call sites in the pipeline.
- [ ] Move or duplicate resume so it happens at the recording → transcribing handoff.
- [ ] Preserve existing behavior for error and cleanup paths.
- [ ] Build and run tests to verify the change.

## Notes

- Keep the change minimal and avoid altering copy/insert behavior beyond media timing.
