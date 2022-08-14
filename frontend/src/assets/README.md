Parcel only includes dependencies it detects are used from JS/HTML code.
However, some assets are still needed but Parcel doesn't detect them, e.g.
- robots.txt
- logo.png - used from elm code directly

So, the files of the static directory are copied to the output bundle by the (parcel-reporter-static-files-copy)[https://github.com/elwin013/parcel-reporter-static-files-copy] Parcel plugin.
Configured in package.json.

