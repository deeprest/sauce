# fs = require 'fs'
# path = require 'path'
# request = require 'request'
# tar = require 'tar'
# exec = (require 'child_process').exec
# config = (require './config')()

#
# Download = (url,filepath)->
#   return new Promise (resolve, reject)->
#     console.log 'Downloading '+url
#     request.get url
#     .on 'response', (rsp)->
#       if rsp.statusCode == 404
#         reject('Bad URL:'+url)
#     .on 'error', (err)->
#       reject('Error connecting to url: '+err)
#     .pipe fs.createWriteStream path.resolve( config.dirDownload, filepath )
#       .on 'finish', ()->
#         console.log 'Finished downloading to '+filepath
#         resolve()
#       .on 'error', (err)->
#         reject('Error writing file: '+err)
#
# exports.Box2D = ()->
# # return Download('https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1','box2d.tar.gz')
# return new Promise (resolve,reject) -> resolve()
# .then ()-> return tar.extract {file:path.resolve(config.dirDownload,'box2d.tar.gz'),cwd:config.dirDownload }, (err, stdout, stderr) -> console.log 'tar extract done'
# .then ()-> return new Promise (resolve,reject) ->
#   exec 'cmake -G "Unix Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
#     if err then reject( 'cmake failed: '+err ); return
#     exec 'cp -r Box2D '+path.resolve(config.dirExternal,'include'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D')}, (err, stdout, stderr) ->
#       if err then reject( 'cp failed: '+err ); return
#       exec 'make config="debug"', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
#         if err then reject( 'make config failed: '+err ); return
#         exec 'cp libBox2D.a '+path.resolve(config.dirExternal,'lib'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build','Box2D')}, (err, stdout, stderr) ->
#           if err then reject( 'cp failed: '+err ); return
#           resolve()
#   # return
# # .catch (reason)-> console.error reason



###
    pushd $EXTERNAL
      curl $CURL_OPTIONS https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1 > box2d.tar.gz
      tar -xf box2d.tar.gz

      if [[ "$SYSTEM" == "linux" ]]; then
        pushd Box2D-2.3.1/Box2D
          ../../../tool/$SYSTEM/premake5 gmake
          cd Build/gmake
          make config="debug" Box2D
          make
        popd
        cp Box2D-2.3.1/Box2D/Build/gmake/bin/Debug/libBox2D.a $SYSTEM

      elif [[ "$SYSTEM" == "darwin" ]]; then
        pushd Box2D-2.3.1/Box2D
          ../../../$TOOL/$SYSTEM/premake5 gmake
          cd Build/gmake
          make config="debug" Box2D
          make
        popd
        cp Box2D-2.3.1/Box2D/Build/gmake/bin/Debug/libBox2D.a $SYSTEM

      elif [[ "$SYSTEM" == "windows" ]]; then
        # Using cmake here because premake5 seems to ENFORCE using VS on windows
        # The following link indicates support for mingw in preamake5 in version 5.0.0-alpha5
        # https://github.com/premake/premake-core/commit/d536aa67e7f97767bb95b570205e44d5a7df85ba
        pushd Box2D-2.3.1/Box2D/Build
        cmake -G "MSYS Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..
        make config="debug" Box2D
        cp Box2D/libBox2D.a ../../../$SYSTEM
        popd
      fi
    popd
###


# AptInstall = (libs,cb) =>
#   emitter = apt.install libs.join(' '), ()->
#     console.log "Done installing "+libs.join(' ')
#     # console.log a for a in Array.prototype.slice.call(arguments);
#     cb? cb()
#   emitter.on 'stdout', (data)->
#     if data? then console.log data
#   emitter.on 'stderr', (err)->
#     if err then console.error err



###
  modules =
    sdl:
      url:'https://www.libsdl.org/tmp/SDL-2.0.4-10002.tar.gz'
      downloadTo:'sdl.tar.gz'
      buildCommand:'cd '+path.resolve(config.dirExternal,'SDL-2.0.4-10002')+'; sudo ./configure; sudo make;'
      #includeDir:'-I' + path.resolve(config.dirExternal, 'SDL-2.0.4-10002','include')
      exec: 'sudo apt-get install sdl2-dev'
      exec: 'brew install sdl2 sdl2_image'
      #linkerArgs: [ '-lSDL2main', '-lSDL2' ]
      # compilerDefines: ['-DGL_GLEXT_PROTOTYPES']

    angelscript:
      url:'http://www.angelcode.com/angelscript/sdk/files/angelscript_2.30.2.zip'
      downloadTo:'angelscript.zip'
      buildCommand:'cd '+path.resolve(config.dirExternal,'sdk','angelscript','projects','gnuc macosx')+'; make;'
      includeDir: [
        '-I' + path.resolve(config.dirExternal, 'sdk', 'angelscript','include')
        '-I' + path.resolve(config.dirExternal, 'sdk', 'add_on', 'scriptbuilder','include')
        '-I' + path.resolve(config.dirExternal, 'sdk', 'add_on', 'scriptstdstring','include')
      ]

    box2d:
      url: 'https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1'
      downloadTo:'box2d.tar.gz'
      buildCommand:'cd '+path.resolve(config.dirExternal, 'Box2D-2.3.1','Box2D','Build')+'; cmake -DBOX2D_INSTALL=ON -DBOX2D_BUILD_SHARED=ON ..; make'

    glm:
      zip: 'https://github.com/g-truc/glm/archive/0.9.8.4.zip'

    mojosetup:
      hg: 'https://hg.icculus.org/icculus/mojosetup/'

###


###
# project directories
EXTERNAL=./external
TOOL=./tool
# options
SYSTEM=unknown
SUDO=sudo
CURL_OPTIONS=-L
GITLFS_CPU=amd64 # 386
GITLFS_VERSION=2.2.1


if [[ "$OSTYPE" == "linux-gnu" ]]; then
  SYSTEM=linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
  SYSTEM=darwin
elif [[ "$OSTYPE" == "msys" ]]; then
  SYSTEM=windows
  SUDO=
  CURL_OPTIONS=-k -L
  # use the MSYS shell to run this script
  # install msys-unzip package to unzip angelscript
  # get curl for mingw from:
  # http://curl.haxx.se/gknw.net/7.40.0/dist-w64/curl-7.40.0-rtmp-ssh2-ssl-sspi-zlib-winidn-static-bin-w64.7z
  # premake5 must be decompressed in /tool/windows if using to build SDL or Box2D
  echo windows sucks donkey balls, so it is not supported yet.
  return
else
  echo OSTYPE not recognized
  exit
fi

DIR_LIB=$(dirname $(pwd))/$EXTERNAL/$SYSTEM
# prepare the target directories
mkdir $EXTERNAL
mkdir $EXTERNAL/$SYSTEM
mkdir $EXTERNAL/$SYSTEM/include
mkdir $EXTERNAL/$SYSTEM/lib
mkdir $EXTERNAL/$SYSTEM/src
mkdir $TOOL/$SYSTEM


function angelscript
{
  pushd $EXTERNAL
    #curl $CURL_OPTIONS http://www.angelcode.com/angelscript/sdk/files/angelscript_2.30.2.zip > angelscript.zip
    unzip angelscript.zip
    rm $SYSTEM/libangel*
    pushd 'sdk/angelscript'
      builddir=''
      if [[ "$SYSTEM" == "linux" ]]; then
        builddir='projects/gnuc'
      elif [[ "$SYSTEM" == "darwin" ]]; then
        builddir='projects/gnuc macosx'
      elif [[ "$SYSTEM" == "windows" ]]; then
        builddir='projects/mingw'
      fi
      pushd $builddir
        ANGELSCRIPT_EXPORT=0
        make clean
        make
      popd
      # mkdir ../../$SYSTEM/lib
      cp lib/libangelscript.a ../../$SYSTEM/lib/libangelscript.a
      # remove dynamic libs so they are not linked with by default
      # (I don't want to modify library makefiles, and I don't know the flag for clang/gcc to force static linking for a given library)
      #rm lib/libangelscript.so lib/libangelscript.dylib lib/delete.me
      cp include/* ../../$SYSTEM/include
    popd
    # rm -r sdk
    # rm angelscript.zip
  popd
}

function box2d
{
  pushd $EXTERNAL
    curl $CURL_OPTIONS https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1 > box2d.tar.gz
    tar -xf box2d.tar.gz

    if [[ "$SYSTEM" == "linux" ]]; then
      pushd Box2D-2.3.1/Box2D
        ../../../tool/$SYSTEM/premake5 gmake
        cd Build/gmake
        make config="debug" Box2D
        make
      popd
      cp Box2D-2.3.1/Box2D/Build/gmake/bin/Debug/libBox2D.a $SYSTEM

    elif [[ "$SYSTEM" == "darwin" ]]; then
      pushd Box2D-2.3.1/Box2D
        ../../../$TOOL/$SYSTEM/premake5 gmake
        cd Build/gmake
        make config="debug" Box2D
        make
      popd
      cp Box2D-2.3.1/Box2D/Build/gmake/bin/Debug/libBox2D.a $SYSTEM

    elif [[ "$SYSTEM" == "windows" ]]; then
      # Using cmake here because premake5 seems to ENFORCE using VS on windows
      # The following link indicates support for mingw in preamake5 in version 5.0.0-alpha5
      # https://github.com/premake/premake-core/commit/d536aa67e7f97767bb95b570205e44d5a7df85ba
      pushd Box2D-2.3.1/Box2D/Build
      cmake -G "MSYS Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..
      make config="debug" Box2D
      cp Box2D/libBox2D.a ../../../$SYSTEM
      popd
    fi
  popd
}

function bullet
{
  echo todo
}

function sdl
{
  if [[ "$SYSTEM" == "linux" ]]; then
    echo todo
    #sudo apt-get install sdl2-dev
  elif [[ "$SYSTEM" == "darwin" ]]; then
    brew install sdl2 sdl2_image
  fi
}

function build-sdl
{
  SDL_ARCHIVE=SDL-2.0.4-10002
  pushd $EXTERNAL
    curl $CURL_OPTIONS https://www.libsdl.org/tmp/$SDL_ARCHIVE.tar.gz > $SDL_ARCHIVE.tar.gz
    tar -xf $SDL_ARCHIVE.tar.gz
    # build SDL
    rm $SYSTEM/libSDL*
    pushd $SDL_ARCHIVE
      mkdir build-$SYSTEM
      cd build-$SYSTEM
      if [[ "$SYSTEM" == "darwin" ]]; then
        CC=$(pwd)/../build-scripts/gcc-fat.sh ../configure
        make clean
        make
      else
        ../configure --prefix=$DIR_LIB
        make clean
        make
        make install
      fi
      ##cp build/lib* ../../$SYSTEM
      #cp build/.libs/libSDL2.a ../../$SYSTEM
      #cp include/* ../../$SYSTEM/include
      #cp ../include/* ../../$SYSTEM/include
    popd
  popd

  SDL_IMAGE_ARCHIVE=SDL2_image-2.0.1
  pushd $EXTERNAL
    #curl $CURL_OPTIONS https://www.libsdl.org/projects/SDL_image/release/$SDL_IMAGE_ARCHIVE.tar.gz > $SDL_IMAGE_ARCHIVE.tar.gz
    tar -xf $SDL_IMAGE_ARCHIVE.tar.gz
    pushd $SDL_IMAGE_ARCHIVE
      ./configure --prefix=$DIR_LIB
      make clean
      make
      make install
    popd
  popd
}

function glm
{
  GLM_VERSION=0.9.8.4
  pushd $EXTERNAL
    if [[ "$SYSTEM" == "linux" ]]; then
      curl -L https://github.com/g-truc/glm/archive/$GLM_VERSION.zip > glm-$GLM_VERSION.zip
      unzip glm-$GLM_VERSION.zip
      cp -r glm-$GLM_VERSION/glm ./$SYSTEM/include
      rm -r glm-$GLM_VERSION
      rm glm-$GLM_VERSION.zip

    elif [[ "$SYSTEM" == "darwin" ]]; then
      curl -L https://github.com/g-truc/glm/archive/$GLM_VERSION.zip > glm-$GLM_VERSION.zip
      unzip glm-$GLM_VERSION.zip
      cp -r glm-$GLM_VERSION/glm ./$SYSTEM/include
      rm -r glm-$GLM_VERSION
      rm glm-$GLM_VERSION.zip
    fi
  popd
}

function json
{
  if [[ "$SYSTEM" == "linux" ]]; then
    # mkdir $EXTERNAL/$SYSTEM/include
    cp $EXTERNAL/json.hpp $EXTERNAL/$SYSTEM/include/json.hpp
  elif [[ "$SYSTEM" == "darwin" ]]; then
    brew tap nlohmann/json
    brew install nlohmann_json
  fi
}

function git-lfs
{
  # https://git-lfs.github.com/
  # NOTE: this needs sudo to install
  GITLFS_ARCHIVE=git-lfs-$SYSTEM-$GITLFS_CPU-$GITLFS_VERSION.tar.gz
  if [[ "$SYSTEM" == "linux" ]]; then
    echo $GITLFS_ARCHIVE
    curl -L https://github.com/git-lfs/git-lfs/releases/download/v$GITLFS_VERSION/$GITLFS_ARCHIVE > $TOOL/$SYSTEM/$GITLFS_ARCHIVE
    # GIT-LFS
    pushd $TOOL/$SYSTEM
      tar -xf $GITLFS_ARCHIVE
      echo presource
      source git-lfs-$GITLFS_VERSION/install.sh
      echo preremove
      rm -r git-lfs-$GITLFS_VERSION
    popd

  elif [[ "$SYSTEM" == "darwin" ]]; then
    # GIT-LFS
    brew install git-lfs
    # pushd tool/darwin
    #   tar -xf git-lfs-darwin-amd64-2.2.1.tar.gz
    #   source git-lfs-2.2.1/install.sh
    # popd
  fi
}

function sauce
{
  SAUCE=external/sauce
  rm -rf $SAUCE
  #git clone https://github.com/deeprest/sauce.git $SAUCE
  git clone /home/zero/project/sauce $SAUCE
  if [[ "$SYSTEM" == "linux" ]]; then
    pushd $SAUCE
      ./setup-sauce.sh
    popd
  elif [[ "$SYSTEM" == "darwin" ]]; then
    ln -s $(brew --prefix llvm)/lib/libclang.dylib $SAUCE/libclang.dylib
    pushd $SAUCE
      ./setup-sauce.sh
    popd
  fi

  # PROJECT_CONFIG=$(pwd)/build.cson
  # pushd $SAUCE
  #   npm run build # coffee
  #   ./sauce --config=$PROJECT_CONFIG setup # gulp
  # popd
}

function physfs
{
  pushd $EXTERNAL
    #hg clone -u release-2.0.3 http://hg.icculus.org/icculus/physfs physfs
    pushd physfs
      mkdir build
      pushd build
        cmake -DPHYSFS_ARCHIVE_ZIP=false -DPHYSFS_ARCHIVE_WAD=false -DPHYSFS_ARCHIVE_QPAK=false -DPHYSFS_ARCHIVE_MVL=false -DPHYSFS_ARCHIVE_HOG=false -DPHYSFS_HAVE_CDROM_SUPPORT=false -DPHYSFS_BUILD_TEST=false -DPHYSFS_BUILD_STATIC=true -DPHYSFS_BUILD_SHARED=false -DPHYSFS_ARCHIVE_7Z=false ..
        make
      popd
    popd
  popd
  cp $EXTERNAL/physfs/build/lib* $EXTERNAL/$SYSTEM/lib
  cp $EXTERNAL/physfs/physfs.h $EXTERNAL/$SYSTEM/include
  rm -rf $EXTERNAL/physfs $EXTERNAL/physfs-build
}

function physfscpp
{
  pushd $EXTERNAL
    git clone https://github.com/kahowell/physfs-cpp.git physfs-cpp
  popd
  cp $EXTERNAL/physfs-cpp/include/*.hpp $EXTERNAL/$SYSTEM/include
  cp $EXTERNAL/physfs-cpp/src/*.cpp $EXTERNAL/$SYSTEM/src
  rm -rf $EXTERNAL/physfs-cpp
}

function mojosetup
{
  pushd $EXTERNAL
    hg clone https://hg.icculus.org/icculus/mojosetup/
  popd
}


SAUCE=external/sauce
PROJECT_CONFIG=$(pwd)/build.cson
pushd $SAUCE
  npm run build # coffee
  ./sauce --config=$PROJECT_CONFIG setup # gulp
popd

## TOOLS
# git-lfs
# sauce
# mojosetup

## LIBRARIES
# json
# glm
# angelscript
# bullet
# box2d
# physfs
# physfscpp
# sdl
# build-sdl


###
