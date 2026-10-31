# Example: Django project

A minimal Django + DRF service (insurance policies API) used to demonstrate and
test the AI harness. It ships with:

- an existing `CLAUDE.md` containing project-specific instructions, to show
  that `setup.sh` preserves developer content and appends a managed block;
- a completed `.ai-harness/project-context.md`, to show that user-owned
  context is never overwritten.

Try it (from the harness root):

```bash
cp -R examples/django-project /tmp/django-demo
./scripts/setup.sh /tmp/django-demo
```
