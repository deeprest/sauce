# Sauce
Nodejs-based local development tool for a C++ game project. Linux and MacOS supported.

Features:
* build tool
* asset processor
* source preprocessor
* script bindings generator
* library updater/builder.

#### What it does
* [Gulp](https://gulpjs.com/) for task management
* Builds project using [LLVM/Clang](http://clang.llvm.org/ "but there's no reason it couldn't use another compiler" )
* [AngelScript](http://www.angelcode.com/angelscript/) bindings can be generated from source
* Renders [Mustache](https://mustache.github.io/) templates
* Filters and copies assets into the build directory on modification
* Project configured from a .cson file (needs work)
* Downloads and builds project libraries from repo or archive
* Incremental builds
* Builds can be triggered by source changes

#### Todo
* Generate installer packages using mojosetup
* Add compiler defines and linker args to build.cson based on externals.
* Re-test AngelScript binding generator
* example project
* write/read the file cache to support caching in between runs

## Details
#### Incremental Builds
 Recommended: run rebuild once before running build to avoid a longer initial build. Only files with changed content are compiled (with command **build**), but they first need to be in the cache. The cache is not stored in between runs, so 'prime' the cache first by running **rebuild** once after starting Sauce. Rebuild is faster than build because it launches many child process at once.

#### Required to generate AngelScript bindings
 - Linux: libclang package must be installed, and the library must be in your path
 - MacOS: libclang.dylib must be in your path, or linked to this directory
 - see documentation for the nodejs package 'libclang'
