# V8 fixture provenance

Byte-identical shared contract fixtures from `johnbenz13/fplnav-spec`:

- Source commit: `49f61537d3d07aefdc05945185e578a5a30c4b18`
- Merged by PR #20: `983762cdfe620880fe6010d49d4033bd165e1d4d`
- Proposed package `@johnbenz13/fplnav-spec@0.3.0` is unpublished.
- Existing npm tooling remains pinned to published 0.2.0 and verifies V5/V7 only.

| Local resource | Shared package path | SHA-256 |
| --- | --- | --- |
| `representative-v8.fplnav` | `examples/v8/representative.fplnav` | `adc5ddeecb39d89692ed4fe216f6416a2186e676cfb5adff62c53af62b342ca5` |
| `v8-nonpositive-override.fplnav` | `tests/fixtures/v8/nonpositive-override.json` | `7c47295a2881d807dc7c220d912c3b8d2cff0e947d5d051a34617a3283d4d1c9` |
| `v8-mismatched-speed.fplnav` | `tests/fixtures/v8/mismatched-speed.json` | `c4fa7d957a40d7a9ff20bfe06f3b101b9cb12072b2009fc78b6cd7c8fe2dbbd3` |
| `v8-missing-wind-solution.fplnav` | `tests/fixtures/v8/missing-wind-solution.json` | `833a8301deb90a52c9d19fea3f57efc6ef5b40cd7aae65f01efb7e1b51891fb4` |

Resource names are unique for Xcode synchronized-resource flattening. These are
synthetic unit-test inputs only, never operational plans.
