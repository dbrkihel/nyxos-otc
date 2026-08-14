#!/usr/bin/env python3
"""Extract the Tibia sound bank (sounds-<hash>.dat) into soundbank.json.

The .dat is a protobuf with no shipped .proto, so the wire format is walked by
hand. Four tables are emitted:

  files    fileId    -> {name, stream}         the actual .ogg on disk
  effects  effectId  -> {type, pitch, gain, files}
  ambience ambientId -> {bed, oneshots}        0x85 kind 0
  music    musicId   -> {file, mode}           0x85 kind 1

`effectId` is what the server sends in the 0x83 magic-effect sound branches;
`type` is the numeric sound type (1..19) that maps to ENumericSoundType 1000+N
and decides which volume channel and which enable checkbox applies. The ambience
and music ids match SoundAmbientEffect_t / SoundMusicEffect_t on the server.

Usage: soundbank.py <sounds-*.dat> <out.json>
"""

import json
import struct
import sys

WT_VARINT, WT_64, WT_LEN, WT_32 = 0, 1, 2, 5


def read_varint(buf, i):
    result = shift = 0
    while True:
        byte = buf[i]
        i += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, i
        shift += 7


def read_fields(buf):
    """Yield (field_number, wire_type, value) for one protobuf message."""
    i = 0
    while i < len(buf):
        key, i = read_varint(buf, i)
        number, wire = key >> 3, key & 7
        if wire == WT_VARINT:
            value, i = read_varint(buf, i)
        elif wire == WT_LEN:
            size, i = read_varint(buf, i)
            value, i = buf[i:i + size], i + size
        elif wire == WT_32:
            value, i = struct.unpack_from('<f', buf, i)[0], i + 4
        elif wire == WT_64:
            value, i = buf[i:i + 8], i + 8
        else:
            raise ValueError('unsupported wire type %d at %d' % (wire, i))
        yield number, wire, value


def to_dict(buf):
    """Group a message's fields by number; every entry is a list."""
    out = {}
    for number, _, value in read_fields(buf):
        out.setdefault(number, []).append(value)
    return out


def float_pair(blob, fallback):
    values = [value for _, _, value in read_fields(blob)]
    return values if len(values) == 2 else fallback


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)

    with open(sys.argv[1], 'rb') as handle:
        top = to_dict(handle.read())

    files = {}
    for blob in top.get(1, []):
        record = to_dict(blob)
        files[record[1][0]] = {
            'name': record[2][0].decode('ascii'),
            'stream': bool(record.get(4, [0])[0]),
        }

    effects = {}
    for blob in top.get(2, []):
        record = to_dict(blob)
        refs = []
        for group in (5, 6):
            for ref in record.get(group, []):
                refs.extend(value for _, _, value in read_fields(ref))
        effects[record[1][0]] = {
            'type': record[2][0],
            'pitch': float_pair(record[3][0], [1.0, 1.0]) if 3 in record else [1.0, 1.0],
            'gain': float_pair(record[4][0], [1.0, 1.0]) if 4 in record else [1.0, 1.0],
            'files': refs,
        }

    ambience = {}
    for blob in top.get(3, []):
        record = to_dict(blob)
        oneshots = []
        for sub in record.get(3, []):
            values = [value for _, _, value in read_fields(sub)]
            if len(values) == 2:
                oneshots.append(values)
        ambience[record[1][0]] = {'bed': record[2][0], 'oneshots': oneshots}

    # Looping beds tied to what is on screen: each group lists the appearance ids
    # that trigger it and tiers of {minimum count -> file}, so a wall of torches
    # sounds fuller than a single one.
    objects = {}
    for blob in top.get(4, []):
        record = to_dict(blob)
        tiers = []
        for sub in record.get(3, []):
            tier = to_dict(sub)
            tiers.append([tier[1][0], tier[2][0]])
        tiers.sort(key=lambda t: t[0])
        objects[record[1][0]] = {'appearances': record.get(2, []), 'tiers': tiers}

    music = {}
    for blob in top.get(5, []):
        record = to_dict(blob)
        music[record[1][0]] = {'file': record[2][0], 'mode': record.get(3, [0])[0]}

    bank = {
        'files': {str(k): v for k, v in sorted(files.items())},
        'effects': {str(k): v for k, v in sorted(effects.items())},
        'ambience': {str(k): v for k, v in sorted(ambience.items())},
        'objects': {str(k): v for k, v in sorted(objects.items())},
        'music': {str(k): v for k, v in sorted(music.items())},
    }
    with open(sys.argv[2], 'w', encoding='utf-8') as handle:
        json.dump(bank, handle, separators=(',', ':'), sort_keys=True)

    missing = sorted({f for e in effects.values() for f in e['files']} - set(files))
    missing += sorted({a['bed'] for a in ambience.values()} - set(files))
    missing += sorted({m['file'] for m in music.values()} - set(files))
    missing += sorted({t[1] for o in objects.values() for t in o['tiers']} - set(files))
    print('files: %d  effects: %d  ambience: %d  objects: %d  music: %d'
          % (len(files), len(effects), len(ambience), len(objects), len(music)))
    if missing:
        print('warning: %d effect refs point at unknown files: %s' % (len(missing), missing[:10]))


if __name__ == '__main__':
    main()
