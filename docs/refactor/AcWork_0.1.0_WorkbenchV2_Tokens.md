# AcWork 0.1.0 WorkbenchV2 Tokens

This phase only establishes the token surface needed by the new scaffold. Most values are still provisional until the HTML prototype lands.

## Token Namespace

```swift
enum WorkbenchV2Tokens {
    enum Layout {}
    enum Spacing {}
    enum Radius {}
    enum Typography {}
    enum Color {}
    enum Border {}
    enum Shadow {}
}
```

## Fixed Values

| Token | Value | Source |
| --- | ---: | --- |
| Default window width | `1500` | Fixed constant |
| Default window height | `920` | Fixed constant |
| Default content width | `1500` | Fixed constant |
| Default content height | `888` | Fixed constant |
| Title bar height | `32` | Fixed constant |
| Minimum window width | `1180` | Fixed constant |
| Minimum window height | `720` | Fixed constant |
| Sidebar width | `216` | Fixed constant |
| Separator width | `1` | Fixed constant |

## Layout Tokens

| Token | Value | Source |
| --- | ---: | --- |
| Page padding top | `20` | Fixed constant |
| Page padding leading | `24` | Fixed constant |
| Page padding bottom | `20` | Fixed constant |
| Page padding trailing | `24` | Fixed constant |
| Content width | `1235` | Fixed constant |
| Header height | `48` | Fixed constant |
| Header bottom gap | `16` | Fixed constant |
| Body top | `84` | Fixed constant |
| Body height | `700` | Fixed constant |
| Footer top | `800` | Fixed constant |
| Footer height | `68` | Fixed constant |
| Main column width | `927` | Fixed constant |
| Context column width | `292` | Fixed constant |
| Compact context column width | `252` | Fixed constant |
| Gutter | `16` | Fixed constant |
| Compact inner padding | `16` | Fixed constant |
| Compact body height | `520` | Fixed constant |
| Compact footer height | `52` | Fixed constant |
| Compact header height | `44` | Fixed constant |

## Typography

| Token | Value | Source |
| --- | ---: | --- |
| Page title | `24` | Fixed constant |
| Header kicker | `12` | Fixed constant |
| Section title | `15` | Fixed constant |
| Card title | `14` | Fixed constant |
| Body | `13` | Fixed constant |
| Caption | `11` | Fixed constant |
| Data | `28` | Fixed constant |
| Value | `19` | Fixed constant |
| Tiny | `10` | Fixed constant |

## Radius / Border / Shadow

| Token | Value | Source |
| --- | ---: | --- |
| Panel radius | `18` | Fixed constant |
| Card radius | `16` | Fixed constant |
| Chip radius | `999` | Fixed constant |
| Small radius | `12` | Fixed constant |
| Border width | `1` | Fixed constant |
| Shadow radius | `8` | Fixed constant |
| Shadow x | `0` | Fixed constant |
| Shadow y | `1` | Fixed constant |
| Shadow opacity | `0.08` | Fixed constant |

## Color Sources

The color palette currently uses system colors:

- `windowBackgroundColor`
- `controlBackgroundColor`
- `underPageBackgroundColor`
- `textBackgroundColor`
- `separatorColor`
- `labelColor`
- `secondaryLabelColor`
- `tertiaryLabelColor`
- `systemBlue`
- `systemGreen`
- `systemOrange`
- `systemTeal`

These are system-derived values rather than custom design tokens.

