# Exposure Therapy – working rules

- SPEC.md is the source of truth. Read the sections relevant to the task before writing code.
- Build only what the current milestone asks for. No extra features, no third-party packages.
- SwiftUI + SwiftData + PhotoKit, iOS 17+, iPhone only. Use async/await.
- Colors come from the asset catalog by name (rose, plum, cream...). Never hard-code hex in views.
- Use the exact copy from SPEC.md, including punctuation.
- Every view gets a #Preview that uses sample data, never the real photo library.
- After changes: build, fix all errors and warnings, and check the Previews before saying you're done.
- Never delete photos except through the Breakup flow in SPEC.md section "Deletion (Breakup)".
- End each task with a short list of what changed and how to test it on device.
