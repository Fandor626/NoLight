# NoLight logo

A lightning bolt split in half: the left half is lit (power is on), the right half is dimmed (power is off).

| File | Use |
|---|---|
| `app-icon.svg` | App icon, default appearance (navy gradient background) → `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| `app-icon-dark.svg` | Dark appearance (transparent background) → `AppIcon-Dark.png` |
| `app-icon-tinted.svg` | Tinted appearance (grayscale, transparent) → `AppIcon-Tinted.png` |
| `logo.svg` | Bolt only (in-app logo, launch screen) → `Logo.imageset` (120 pt tall) |
| `preview.png` | Default / dark / tinted preview |

Re-export (needs `rsvg-convert`):

```sh
rsvg-convert -w 1024 -h 1024 design/logo/app-icon.svg -o App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
rsvg-convert -w 1024 -h 1024 design/logo/app-icon-dark.svg -o App/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png
rsvg-convert -w 1024 -h 1024 design/logo/app-icon-tinted.svg -o App/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png
for s in 1 2 3; do rsvg-convert -h $((120*s)) design/logo/logo.svg -o App/Assets.xcassets/Logo.imageset/Logo@${s}x.png; done
```

The default app icon must have no alpha channel (App Store requirement); flatten it after export if needed.
