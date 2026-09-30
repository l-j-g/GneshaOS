# Dictation

The CF-FV1's **変換** key immediately right of Space toggles recording.
Press once, speak, then press again. **Shift+変換** cancels without typing.
This replaces the old hold-for-HJKL-arrows layer. 無変換 remains Escape.

Voxtype transcribes locally with Whisper, then OpenCode Go's
`glm-5.3-flash` model cleans punctuation, grammar and filler words. Text is
sent to OpenCode's API using the existing credential in
`~/.local/share/opencode/auth.json`; it is typed into the focused app and
never automatically submitted. Keep the destination focused until typing
finishes. If cleanup fails or takes over 25 seconds, Voxtype uses the
original transcription. Review model output before sending it.

Preferences are in `home/variables.nix`, under `dictation`. The defaults
are English `base.en` speech recognition and OpenCode Go
`glm-5.3-flash` cleanup. This keeps the CF-FV1's CPU work limited to speech
recognition while using the subscription's hosted model.

After an explicitly approved system/Home Manager activation, the first
session start downloads the speech model into user-owned storage. Allow
network access for that first start. Desktop notifications indicate start
and stop; the optional Voxtype waveform OSD is disabled because the packaged
daemon does not include an OSD frontend.
The microphone's existing mute state is respected; unmute it with the
microphone mute key or the audio controls before dictating.

Check readiness:

```sh
systemctl --user status voxtype
journalctl --user -u voxtype -n 50
voxtype setup check
```

Both NixOS activation (keyd remapping) and Home Manager activation (the
dictation service and Sway binding) are needed. Builds alone do not install
the binding. First test in an empty editor with a short sentence, then test
cancellation and a sentence containing a question: cleanup should preserve
the question rather than answer it.
