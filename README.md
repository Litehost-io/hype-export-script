# Litehost export script for Tumult Hype

Adds **Litehost** to **File › Export as HTML5** in Tumult Hype. Hype exports your document, the script zips it, uploads it to [Litehost](https://litehost.io) and copies a link that plays the animation in any browser, on any phone.

- No account needed for exports up to 2 MB. The link stays online for 15 minutes; sign in (free, Google or email) to keep it.
- Bigger exports show a message with a link to upload them from a free account.
- Plain shell script (`zip`, `curl`, `osascript`), so it works without Hype's Python enabler.

Full guide, with what to check before sending the link to a client: https://litehost.io/guides/send-hype-animation-to-client

## Install

1. Download `Litehost.hype-export.sh`.
2. In Hype, open **Settings › Export** and click the button that opens the export scripts folder (`~/Library/Application Scripts/com.tumult.Hype4/`).
3. Move the script there and make it executable:
   ```
   chmod 755 ~/Library/Application\ Scripts/com.tumult.Hype4/Litehost.hype-export.sh
   ```
4. Restart Hype. **File › Export as HTML5 › Litehost** appears.

## What it sends

Only the exported files, as one ZIP, to `https://connect.litehost.io/v1/projects/temp`. Nothing else leaves your Mac. The response gives the public link and a claim link to keep it.

## License

MIT
