# Sauce
A simple Node.js C++ build tool

* Coffeescript
* Nodejs
* Gulp
* Clang++

## Features
- non-blocking pre-build and post-build steps, such as copying binary assets for a packaged build
- optionally watches source directories for changes and triggers a build (full rebuild for now)
- (devs) optionally can watch its own source and "self-recompile"

## Todo
- incremental builds. compile object files on demand and incremental linking.

## Note
- Linux: libclang package must be installed, and the library must be in your path
- MacOS: libclang.dylib must be in your path, or linked to this directory
- see documentation for the nodejs package 'libclang'
