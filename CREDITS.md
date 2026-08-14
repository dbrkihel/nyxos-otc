# Credits

## This client

**nyxos-otc** — maintained by **BRKiHeL**.

A Tibia 15.25 client: protocol work, a rebuilt options menu, a full audio
subsystem, the Cip-style NPC dialogue window, and minimap persistence. See the
[README](README.md) for what is actually implemented.

## Open-source credits

Built on the work of:

- [**OTClient**](https://github.com/edubart/otclient) — edubart. The engine:
  framework, renderer, Lua binding layer, OTUI/OTML.
- **OTClientV8** — performance work and protocol extensions.
- [**AstraClient**](https://github.com/Mateuzkl/AstraClient) — Mateuzkl /
  Equipe Skyyzyy.

Original license headers and required open-source credits are retained in the
source files. See [LICENSE](LICENSE).

## Third party

- **ANGLE** (Google) — vendored in `third_party/angle` for the DirectX backend
- **qrcodegen** — Nayuki, <https://www.nayuki.io/page/qr-code-generator-library>
- **TinyXML** — Lee Thomason
- **base64.lua** — Ilya Kolbin

Build dependencies (OpenAL, FreeType, libprotobuf, zlib, LuaJIT, OpenSSL, Boost)
are pulled through vcpkg or your distribution and keep their own licenses.

## Not included

Tibia game assets are the property of **CipSoft GmbH** and are not distributed
with this repository. "Tibia" is a registered trademark of CipSoft GmbH. This
project is not affiliated with, endorsed by, or sponsored by CipSoft.
