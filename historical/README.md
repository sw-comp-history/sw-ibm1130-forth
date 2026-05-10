# `historical/` -- redistributed historical artifacts

This directory holds **redistributed** historical content that we
ship as part of this repo (unlike `reference/`, which is gitignored
and consulted read-only). Each subdirectory carries its own
`NOTICE` file and attribution.

Redistribution policy (per `docs/references.md` Sec "License
hygiene"):

- We only redistribute content whose upstream provenance gives us
  clear permission. Each subdirectory's `NOTICE` records the
  permission we are relying on.
- Redistribution preserves attribution: the original author's
  name, the year of the original work, the source of the upstream
  copy we translated from, and any conditions placed by the
  upstream rights-holder.
- Translations and adaptations document every transformation in
  a `TRANSLATION-LOG.md` so a reader can compare our copy to the
  upstream and see exactly what changed.

## Subdirectories

| Path                      | Contents                                          |
| ------------------------- | ------------------------------------------------- |
| `forth68/`                | Translation of Charles H. Moore's 1968 FORTH for the IBM 1130, retargeted to our `sw-ibm1130-asm` syntax. |
