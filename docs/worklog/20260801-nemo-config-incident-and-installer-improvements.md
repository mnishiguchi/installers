# Nemo configuration incident

After a clean LMDE 7 installation, opening Nemo Preferences caused Nemo to use
approximately 100% CPU and become unresponsive. Reinstalling Nemo, rebooting,
resetting its settings, and changing GTK-related options did not help. Nemo
worked with a clean `XDG_CONFIG_HOME`, indicating that existing user
configuration was responsible, although the exact file was not identified.

No Nemo-specific workaround was added because the incident appears isolated.
The bootstrap instead gained a general, non-destructive ownership check for
user-state directories and clearer guidance against restoring `~/.config`,
`~/.cache`, or `~/.local` wholesale. It does not delete configuration, reset
Nemo, or repair ownership automatically.
