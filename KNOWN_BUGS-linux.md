Known Bugs
ICC licence acceptance can temporarily leave the engine stopped

Status: Known
Affected: GUI first-run ICC licence acceptance
Observed: Linux

On the first launch of a newly installed copy, accepting the Adobe colour-profile licence can leave the Python engine stopped until Spectra PDF is restarted.

Typical sequence:

Spectra PDF starts normally and reports engine: ready.
The ICC colour-profile licence dialog is shown.
The user clicks Accept.
The assent is recorded successfully.
The running engine is killed so that a new process can inherit the updated SPECTRAPDF_ICC_ASSENT environment variable.
The engine is not immediately restarted.
Attempting to open a PDF can therefore report engine not running.
Restarting Spectra PDF starts the engine normally, and subsequent operation works.

The relevant implementation is src-tauri/src/portable.rs calling crate::engine::restart_for_assent(), with the latter currently implemented in src-tauri/src/engine.rs by removing and killing the current CommandChild.

The intended design is for the engine to be restarted with the newly recorded assent. The current implementation only terminates the existing child and relies on a later engine-start path, which can leave a gap in which the application has no running engine.

The termination may also appear in the log as:

[engine] exited with TerminatedPayload { code: None, signal: Some(9) }


This is consistent with the intentional child.kill() operation and should not, by itself, be interpreted as evidence that the Python engine crashed.

Platform scope

This is not known to be intrinsically Linux-specific. The engine restart code is shared across platforms. The bug was observed on Linux; Windows may currently avoid exposing the gap because of differences in subsequent application behaviour or timing, but that has not been established as a guarantee.

Possible fix

Make restart_for_assent() start the replacement engine immediately after terminating the old one, rather than leaving the engine absent until a later operation happens to start it. Preferably propagate a failure to start the replacement engine back through the assent command instead of silently leaving the application without an engine.

Reproduction

Install a freshly built DEB with no existing ICC assent record, launch spectrapdf, accept the ICC licence, and immediately attempt to open a PDF without restarting the application.