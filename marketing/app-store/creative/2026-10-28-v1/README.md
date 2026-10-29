# GrowingUp App Store creative assets — first concept, 28 October 2026

A matching text-free pair for the product page Header and Search Results.
Reusable for English and Russian. Created here using the built-in OpenAI
image_gen tool. The tool does not report or allow selection of its underlying
model version; do not label these as verified GPT Image 2.5 output.

## Files

| File | Use | Pixels |
| --- | --- | --- |
| header_3840x1646.png | Header upload | 3840 × 1646 |
| search_3840x2560.png | Search Results upload | 3840 × 2560 |
| source_header_1536x1024.png | Original generated header composition | 1536 × 1024 |
| source_search_1536x1024.png | Original generated search composition | 1536 × 1024 |

The upload files are 8-bit RGB PNGs without an alpha channel, encoded with
sRGB color metadata. They are resized from the original 1536 × 1024 generations,
not natively generated at the final resolution. The header is cropped to the
central 1536 × 658 band before resizing. Originals are preserved.

## Reproduce the technical export

The committed exports already sit in this directory, and `-n` never
overwrites them, so export into a new directory. Run from this directory:

```sh
mkdir -p export
ffmpeg -n -i source_header_1536x1024.png -vf "crop=1536:658:0:183,scale=3840:1646:flags=lanczos,format=rgb24" -frames:v 1 -update 1 export/header_3840x1646.png
ffmpeg -n -i source_search_1536x1024.png -vf "scale=3840:2560:flags=lanczos,format=rgb24" -frames:v 1 -update 1 export/search_3840x2560.png
```

Embed the standard macOS sRGB ICC profile after exporting:

```sh
sips --embedProfile "/System/Library/ColorSync/Profiles/sRGB Profile.icc" export/header_3840x1646.png export/search_3840x2560.png
```

The PNG exports carry sRGB color metadata; sips identifies them as sRGB IEC61966-2.1.
See validation.json for dimensions, channel mode and checksums.

## Try the same prompts in web ChatGPT

1. Paste header-prompt.txt to generate the Header source.
2. In the same conversation, attach that generated header and paste
   search-prompt.txt. Its image reference is the Header, used to match the
   characters and art direction.
3. Compare the two sets at their final aspect ratios. A raw 3:2 Header source
   still needs its central 21:9 crop before upload.

All characters are fictional. The images contain no visible text, so no
language-specific artwork variant is needed.

## Sources and reference

- WhoGaveWhat: docs/store-assets/creative/README.md in that repository,
  including its saved Header/Search prompts and original/exported PNGs.
  The existing workflow used two separate compositions, a central Header
  crop and Lanczos resizing.
- GrowingUp: app icon cyan, lime and yellow accents, current family-photo
  identity, loved-one age tracking and birthdays.
- [Apple creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)
- [Apple asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
- [OpenAI image generation documentation](https://developers.openai.com/api/docs/guides/tools-image-generation)

Danis compared these with his own web ChatGPT generations, chose this pair
and uploaded header_3840x1646.png and search_3840x2560.png to App Store
Connect himself on 28 October 2026. The SHA-256 values in validation.json
identify the uploaded files.
