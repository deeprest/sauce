# Sauce
Node.js build tool for simple C++ projects

## Features
* Clang++ for compiler frontend
* CSON project config files
* Uses Gulp for incremental builds and custom build tasks (will use new version of Gulp when it's out)

### Extra Features 
* the node module 'libclang' can be used to generate script bindings)
* self-compiling. Watches for changes to the build script (itself), recompiles the coffee source, and runs everything else in a separate process
* auto-builds. Watches for changes to source/header files and builds the executable on-demand (full rebuild for now)
* runs template task; for custom preprocessing of source. (Mustache templates)
* generates AngelScript bindings from C++ headers
* copies assets for a packaged build. (TODO) packages build

## Todo
+ load project/build config from json
- tiney example project
- incremental builds. compile object files on demand and incremental linking.
- package a build

### Required to generate AngelScript bindings
- Linux: libclang package must be installed, and the library must be in your path
- MacOS: libclang.dylib must be in your path, or linked to this directory
- see documentation for the nodejs package 'libclang'
