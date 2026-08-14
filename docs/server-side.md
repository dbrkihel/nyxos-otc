---
title: Server-side changes
layout: default
nav_order: 6
---

# Server-side changes

Most of this client works against an unmodified server. A few features need the
server to send something it does not send by default. This page lists those, and
what to change.

Examples are written against [Canary](https://github.com/opentibiabr/canary) /
Crystal Server, which is what this client is developed against. Paths on other
forks will differ, but the protocol facts do not.

---

## Ambient sounds and music

**What you get:** zone ambience (city noise, cave wind, water) and server-driven
music tracks, with smooth distance fade and stereo positioning on the client.

### The protocol

Opcode **`0x85`** carries both:

```
uint8   kind      0 = ambient, 1 = music
uint16  id        0 means silence (this is how you stop a track or ambience)
```

{: .important }
> `0x85` was the *distance missile* opcode in older protocols. In the modern
> protocol distance shots moved into the `0x83` effect loop and `0x85` was
> reused for sound. If your client still parses `0x85` as a missile it reads 12
> bytes against the packet's 3, and everything after it in that frame is
> misread — the visible symptom is creatures appearing to teleport. This client
> parses it correctly; the note is here for anyone porting the change.

### 1. Expose the sound enums to Lua

The ambient and music ids are C++ enums the scripting layer cannot see until you
register them. In `src/lua/functions/core/game/lua_enums.cpp`, inside
`effectsSoundEnums`:

```cpp
// Ambient and music ids share the sound namespace, which is what scripts
// already assume when they say SOUND_EFFECT_TYPE_AMBIENT_*.
for (const auto value : magic_enum::enum_values<SoundAmbientEffect_t>()) {
    registerMagicEnumNamespace(L, soundNamespace, value);
}
for (const auto value : magic_enum::enum_values<SoundMusicEffect_t>()) {
    registerMagicEnumNamespace(L, soundNamespace, value);
}
```

Recompile the server. Without this, any script referencing
`SOUND_EFFECT_TYPE_AMBIENT_*` gets `nil` and silently sends nothing.

### 2. Give your zones an area

Ambience is driven by zone enter/leave events, so a zone with no registered area
never fires. A zone declared in a script but never given coordinates is the most
common reason "ambience does nothing" after step 1.

```lua
local zoneAreas = {
    ["thais-city"] = { { x = 32289, y = 32138, z = 0 }, { x = 32445, y = 32294, z = 15 } },
}

for name, area in pairs(zoneAreas) do
    Zone(name):addArea(area[1], area[2])
end
```

Pick the bounding box from your own map. Repeat per city.

### 3. Map zones to sounds

```lua
local ambientZones = {
    {
        zone = "thais-city",
        soundEnterDay = SOUND_EFFECT_TYPE_AMBIENT_SWAMP_INSECTS_BIRDS_NOISES_CITY,
        soundEnterNight = SOUND_EFFECT_TYPE_AMBIENT_WIND_NOISES_CREATURES_INSECTS_NIGHT,
        soundLeave = SOUND_EFFECT_TYPE_AMBIENT_SILENCE,
    },
}
```

Then register enter/leave handlers on each `Zone(zoneData.zone)` that send the
matching sound. `SOUND_EFFECT_TYPE_AMBIENT_SILENCE` is id 0 — the stop signal.

---

## Combat, spell and item sounds

These arrive inside the **`0x83`** graphical-effects loop, which most servers
already send. No server change is normally needed.

What the client does with them: each effect id resolves through
`data/sounds/soundbank.json` to a numeric type (1–19). The type decides which
volume slider and which enable checkbox applies, and the packet's *source*
(your own actions, another player, a creature) decides which battle group it
falls into.

If a category is silent, check that your server sends a source on the effect —
a creature-sourced effect with no source byte is treated as global.

---

## Anti-multibox HWID handshake

If you use the HWID challenge, the client and server share a secret.

In `src/client/protocolgameparse.cpp`:

```cpp
constexpr const char* HWID_SECRET = "CHANGE_ME_SharedHwidSecret_v1";
```

{: .warning }
> **Change this before running a public server.** It ships as a placeholder and
> is published in this repository, so the value as-shipped can be forged by
> anyone who reads the source. Change it here *and* in `huntMonitorHwidSecret`
> on the server — they must match exactly, and rotating one without the other
> locks every player out.

The client answers the challenge with a keyed MAC over SHA-1, bound to the
session nonce. It also appends its build number as an unsigned `|<build>`
suffix outside the MAC, which the server can read for diagnostics
(`player:getClientBuild()`); clients that omit it read as build 0.

---

## NPC dialogue window

The Cip-style dialogue window is driven by **extended opcode `0x1C`**. Your
server needs to send the dialogue payload on that opcode for the window to open;
otherwise NPC conversation falls back to the normal chat channel.

For older TFS 0.x-family servers that lack extended opcode support entirely,
`tools/tfs_extendedopcode.patch` in this repository adds the
`CREATURE_EVENT_EXTENDED_OPCODE` plumbing (`onExtendedOpcode`) and the
`CLIENTOS_OTCLIENT_*` operating-system values the client reports.

---

## Login

The client sends its release version as `release_version` on login. If you gate
logins on a published client version, that is the field to check. Leaving the
gate off is fine — the client does not require it.

---

## Checklist

| Feature | Server change needed |
|---|---|
| Combat / spell / item sounds | None (uses `0x83`) |
| UI sounds, music on login screen | None (client-side) |
| Zone ambience | Register sound enums, give zones areas, map zones to sounds |
| Server-driven music | Send `0x85` with `kind = 1` |
| NPC dialogue window | Send extended opcode `0x1C` |
| HWID anti-multibox | Matching shared secret |
| Minimap persistence | None (client-side) |
