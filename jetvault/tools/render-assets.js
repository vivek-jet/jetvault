#!/usr/bin/env node
// Regenerates every JetVault raster asset from the SVG sources in jetvault/branding.
//
//   npm install --prefix /tmp/jv-render @resvg/resvg-js@2
//   NODE_PATH=/tmp/jv-render/node_modules node jetvault/tools/render-assets.js
//
// Outputs:
//   jetvault/web-vault/**      overlay copied on top of the prebuilt web vault
//   src/static/images/*.png    admin panel, 404 page and email images (same file names as upstream)

const fs = require("fs");
const path = require("path");
const { Resvg } = require("@resvg/resvg-js");

const root = path.resolve(__dirname, "../..");
const brand = path.join(root, "jetvault/branding");
const overlay = path.join(root, "jetvault/web-vault");
const staticImages = path.join(root, "src/static/images");

const svg = (name) => fs.readFileSync(path.join(brand, name), "utf8");
const icon = svg("icon.svg");
const iconWhite = svg("icon-white.svg");
const logo = svg("logo.svg");
const logoWhite = svg("logo-white.svg");
// Full-bleed square for platforms that apply their own mask (iOS, Android, Windows tiles)
const iconSquare = icon.replace('rx="60"', 'rx="0"');

function render(source, fit, value) {
  return new Resvg(source, {
    fitTo: { mode: fit, value },
    font: { loadSystemFonts: true, defaultFontFamily: "Helvetica" },
  })
    .render()
    .asPng();
}

function write(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
  console.log("wrote", path.relative(root, file));
}

// PNG-compressed ICO containing several sizes
function ico(source, sizes) {
  const images = sizes.map((s) => render(source, "width", s));
  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);
  let offset = header.length;
  images.forEach((img, i) => {
    const e = 6 + 16 * i;
    header.writeUInt8(sizes[i] >= 256 ? 0 : sizes[i], e);
    header.writeUInt8(sizes[i] >= 256 ? 0 : sizes[i], e + 1);
    header.writeUInt16LE(1, e + 4);
    header.writeUInt16LE(32, e + 6);
    header.writeUInt32LE(img.length, e + 8);
    header.writeUInt32LE(offset, e + 12);
    offset += img.length;
  });
  return Buffer.concat([header, ...images]);
}

const vault = (p) => path.join(overlay, p);

// Web vault overlay
write(vault("images/logo.svg"), logo);
write(vault("images/logo-white.svg"), logoWhite);
write(vault("images/icon-white.svg"), iconWhite);
write(vault("images/safari-pinned-tab.svg"), iconWhite.replace('fill="#FFFFFF"', 'fill="#000000"'));
write(vault("images/logo-dark@2x.png"), render(logo, "height", 86));
write(vault("images/logo-white@2x.png"), render(logoWhite, "height", 86));
write(vault("images/icon-dark.png"), render(icon, "width", 32));
write(vault("images/icon-white.png"), render(iconWhite, "width", 32));
write(vault("images/favicon-16x16.png"), render(icon, "width", 16));
write(vault("images/favicon-32x32.png"), render(icon, "width", 32));
write(vault("images/apple-touch-icon.png"), render(iconSquare, "width", 180));
write(vault("images/mstile-150x150.png"), render(iconSquare, "width", 270));
for (const size of [192, 512]) {
  const png = render(iconSquare, "width", size);
  write(vault(`images/android-chrome-${size}x${size}.png`), png);
  write(vault(`images/icons/android-chrome-${size}x${size}.png`), png);
}
write(vault("favicon.ico"), ico(icon, [16, 32, 48]));

// Server side images (admin panel, 404 page, emails)
write(path.join(staticImages, "vaultwarden-icon.png"), render(icon, "width", 64));
write(path.join(staticImages, "vaultwarden-favicon.png"), render(icon, "width", 32));
// Email header logo, rendered at 2x for high-DPI mail clients
write(path.join(staticImages, "logo-gray.png"), render(logo, "height", 78));
write(path.join(staticImages, "404.png"), render(svg("404.svg"), "width", 500));
