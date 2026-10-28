# GrowingUp app icon: Soft Lift

Round 3, third option ("Soft Lift") was selected as the app icon: a closed
green/lime/yellow ring, cyan arrows at the top (pointing right) and bottom
(pointing left), a single cyan clock hand, and a narrow local glow with a faint
short shadow on a solid white background.

## Files

| File | Description |
| --- | --- |
| [source.png](source.png) | Approved 1254x1254 opaque RGB source (`lift.png` from the round 3 concepts; near-white pixels already normalized to `#FFFFFF`). |
| [prompt.txt](prompt.txt) | Exact generation prompt for the source (`lift-prompt.txt`). |
| [`GrowingUp/Assets.xcassets/AppIcon.appiconset/Icon.png`](../../../GrowingUp/Assets.xcassets/AppIcon.appiconset/Icon.png) | Exported 1024x1024 app icon. |

- Source: 1254x1254, 8-bit RGB, no alpha.
- SHA-256 of `source.png`:
  `2c65f80cea5d046c962a317b3e5cf8fa465027cfcd5a8da619c81989ed4c2d09`
- Export: 1024x1024, 8-bit RGB (PNG color type 2), no alpha, non-interlaced,
  tagged sRGB.

## Reproduce the export

Run from the repository root (requires FFmpeg and macOS `sips`):

```sh
ffmpeg -v error -y -i marketing/app-icon/soft-lift/source.png \
  -vf "scale=1024:1024:flags=lanczos,format=rgb24" \
  -frames:v 1 -update 1 -compression_level 9 -pix_fmt rgb24 \
  /tmp/softlift-icon.png

sips --embedProfile "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
  /tmp/softlift-icon.png \
  --out GrowingUp/Assets.xcassets/AppIcon.appiconset/Icon.png
```

The icon is a full-bleed square with no rounded corners and no transparency;
iOS applies the mask. `Contents.json` declares the single universal 1024x1024
image and the target builds it through `ASSETCATALOG_COMPILER_APPICON_NAME`
`AppIcon`.

Validated with Xcode's `actool` for iOS: the compiled asset catalog contains
an opaque 1024x1024 sRGB `AppIcon` rendition, and the generated bundle metadata
names `AppIcon` as `CFBundlePrimaryIcon`. The source PNG has valid chunk CRCs,
no alpha or transparency chunk, and no animation. No App Store upload is
needed separately for the icon; App Store Connect reads it from a future
uploaded build. This PR does not upload or release a build.

## Apple references

- [Configuring your app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/)
