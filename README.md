 <p align="center">
  <img src="assets/gfx/logo.png" alt="Ogmo Editor 3"/>
</p>

### Open Source 2D level editor written in Haxe!

> **Note:** This is a fork of [Ogmo Editor 3 - Community Edition](https://github.com/Ogmo-Editor-3/OgmoEditor3-CE) with updated instructions.

## Quick Start
```
nvm use 16

haxelib setup
haxelib install electron 12.0.4
haxelib install jQueryExtern (I'm using 3.3.0)
haxelib install haxe-loader (I'm using v1.1.1)

npm install --legacy-peer-deps

-- to develop
npm run dev

-- build the app
npm run build


-- create desktop application
-- for macOs
npm run dist

-- for macOs (Intel) (Unverified)
npm run distintel


-- for windows (Unverified)
npm rund distw

Use the application, it's a much better experience than dev
```

For more information, check out the [Ogmo 3 homepage](https://ogmo-editor-3.github.io/). Or just go straight to the [downloads page](https://ogmoeditor.itch.io/editor)! If you need a build for 32 bit Windows, @vontoGH has graciously made them [available here](https://github.com/vontoGH/OgmoEditor3-CE/releases)!

# Getting Started

This project requires Haxe v4.0.0 or later, Node v16, and various dependencies for each of them.

### Node
* Install [Node](https://nodejs.org/)

### Haxe
* Install [Haxe](https://haxe.org/download/)
* Run the following commands:
```
haxelib setup
haxelib install electron 12.0.4
haxelib install jQueryExtern (I'm using 3.3.0)
haxelib install haxe-loader (I'm using v1.1.1)
```

## Build
```
npm install --legacy-peer-deps
npm run build
```
This builds the App and puts it in the `bin` directory. You can then start the app by running `npm start`, or by starting electron in the directory.

## Development
```
npm run dev
```

## Packaging
```
npm install --legacy-peer-deps
npm run build
npm run dist
```
This builds, then packages the App into an executable.

# Credits
 - Created by [Maddy Thorson](https://twitter.com/MaddyThorson) and [Noel Berry](https://twitter.com/noelfb)
 - Icons & Logo by [Kyle Pulver](https://twitter.com/kylepulver)
 - Ported to Haxe and extended by [Caleb Cornett](https://twitter.com/thespydog), [Will Blanton](https://twitter.com/x01010111), and [Austin East](https://twitter.com/austinweast)
