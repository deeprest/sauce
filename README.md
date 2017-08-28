# Sauce
indie game development tool for C++ projects

## Features
* [Gulp](https://gulpjs.com/) for task management
* [AngelScript](http://www.angelcode.com/angelscript/) bindings can be generated from source
* [Mustache](https://mustache.github.io/) templates are processed
* Processes and copies assets into the build directory on modification
* Builds can be triggered by source changes
* Builds project using [Clang](http://clang.llvm.org/ "but there's no reason it couldn't use another compiler" )
* Project configured from a .cson file (needs work)
* Downloads and builds project libraries from repo or archive

## Todo
* Incremental builds (gulp-changed)
* Generate installer packages using mojosetup
* Re-test AngelScript binding generator
* example project
* generate CMakeLists.txt?
* cleanup: remove unnecessary node modules

### Required to generate AngelScript bindings
- Linux: libclang package must be installed, and the library must be in your path
- MacOS: libclang.dylib must be in your path, or linked to this directory
- see documentation for the nodejs package 'libclang'
