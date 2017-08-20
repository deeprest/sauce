# Sauce
A Node.js C++ build tool

* Coffeescript (pretty javascript)
* Nodejs (non-blocking I/O and server functionality)
* Gulp (streaming builds, custom tasks)
* Clang++ (preferred because the node module 'libclang' can be used to generate script bindings)

* self-compiling. Watches for changes to the build script (itself), recompiles the coffee source, and runs everything else in a separate process
* auto-builds. Watches for changes to source/header files and builds the executable on-demand (full rebuild for now)
* runs template task; for custom preprocessing of source. (Mustache templates)
* generates script bindings from C++ headers. (AngelScript)
* copies binary assets for a packaged build. (TODO) packages build


## Todo
- load project/build config from json
- incremental builds. compile object files on demand and incremental linking.

## Note
- Linux: libclang package must be installed, and the library must be in your path
- MacOS: libclang.dylib must be in your path, or linked to this directory
- see documentation for the nodejs package 'libclang'
