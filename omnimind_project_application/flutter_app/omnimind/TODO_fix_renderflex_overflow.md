# TODO: Fix RenderFlex overflow (horizontal)

- [ ] Identify the exact offending RenderFlex in the Flutter UI (likely a Row in patient_home.dart / patient_dashboard.dart).
- [ ] Add layout constraints so horizontal children can wrap/fit:
  - [ ] Replace fixed-width/long text Rows with `Flexible`/`Expanded`.
  - [ ] For long labels, use `Text(…, softWrap: false/true, overflow: TextOverflow.ellipsis)` as appropriate.
  - [ ] For fixed-size icon+text nav items, ensure each item is constrained (e.g., remove `width: selected ? 20 : 0` if causing tight sizing).
- [ ] If content may legitimately exceed, wrap the Row in `SingleChildScrollView(scrollDirection: Axis.horizontal)` or use `ClipRect`.
- [ ] Run `flutter analyze` and (if available) `flutter test` / run debug build to confirm no more `RenderFlex overflowed` warnings.

