# Recommendations

| Date | Source | Observation | Impact | Action | Status |
| --- | --- | --- | --- | --- | --- |
| 2026-03-30 | UI Changes | Ensure Navigation Split Views handle `EmptyView` with properly matching layouts. `EmptyView()` can have non-zero layouts padding unless actively set with `min: 0, ideal: 0, max: 0` during explicit single-column routing. | Minor | Update templates to define EmptyViews precisely. | Open |
