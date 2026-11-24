# Build 62 recovery

Base: v0.4.52 / Build 59, commit 5d60edc01dafc66c814c488387ae63b29371334f.

The wallet presentation, layout and gesture files plus original tests are restored byte-for-byte to this baseline. Build 60/61 animation changes are superseded by this recovery. Existing account, card and protected data schemas remain unchanged. Do not reset user data or attempt to undo saved card order.

Validation: verify exact restored file bytes, original cover hashes, Swift motion tests and unsigned device build in CI. Simulator UI validation is separate and must be reported according to actual logs; physical-device acceptance is pending.
