# Third-party notices

## Lumina / Luminati

Parts of this game are ported from Lumina (https://gitlab.com/stubborn-hug/lumina), an
open-source HD-2D engine for three.js. They were rewritten for Godot and adapted to this game.

| What | From Lumina | Here |
| --- | --- | --- |
| Colour grade with vignette and grain (simplified) | `src/engine/render/shaders/GradeShader.js` | `shaders/climb/grade.gdshader` (climbing screen and walking world) |
| Wrapped light and a normal bent towards the camera and up for sprites | `src/engine/sprite/Sprite3D.js` | `shaders/overworld/sprite.gdshader` |
| Light shafts: one quad turned around its axis, soft falloff, fades, slow streaks | `src/engine/fx/GodRays.js` | `shaders/overworld/godrays.gdshader` |

```
MIT License

Copyright (c) 2026 Luminati

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Ninja Adventure

The four menu sounds in `assets/ninja_adventure/Audio/Sounds/Menu` come from the Ninja
Adventure pack, released under CC0 1.0; see `assets/ninja_adventure/LICENSE.txt`.

## IM FELL English

The lettering of the topo uses IM FELL English (Roman and Italic) by Igino Marini, from the
Google Fonts collection, under the SIL Open Font License 1.1: `assets/fonts/imfell/`, with the
licence in `assets/fonts/imfell/OFL.txt`. The font files are unchanged.

## Kenney Fonts

The pixel fonts of the menus and the walking world (Kenney Pixel, Kenney Mini and others in
`assets/fonts/kenney_kenney-fonts/`) are made by Kenney (www.kenney.nl) and released under
CC0 1.0; see `assets/fonts/kenney_kenney-fonts/License.txt`.
