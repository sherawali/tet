# Flutter local SQLite split

- `content_schema.sql` defines replaceable/synchronised question-bank content.
- `user_schema.sql` defines local-only attempts, bookmarks, mocks and progress.

The Flutter app must open these as separate database files. Content snapshot replacement or delta
installation must never touch `user.sqlite`. Deleted/retired question IDs may remain referenced in
user history so past mock results remain readable.
