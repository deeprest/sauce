os = require 'os'
path = require 'path'

module.exports = ->
  # config expressions
  this.platform = os.platform()
  this.dirRoot = path.resolve( process.cwd(), '..', '..')
  this.dirSource = path.resolve( this.dirRoot, 'code')
  this.dirGeneratedSourceOutput = path.resolve( this.dirSource, 'mustached')
  this.dirLibrary = path.resolve( this.dirRoot, 'external')
  this.dirBuildRoot = path.resolve( this.dirRoot, 'dev-build')
  this.dirOutput = path.resolve( this.dirBuildRoot, this.platform)
  this.dirObj = path.resolve( this.dirBuildRoot, '.obj')
  this.dirTool = path.resolve( this.dirRoot, 'tool')
  this.dirAsset = path.resolve( this.dirRoot, 'asset')
  this.includeDirectories = [
    '-I' + path.resolve( this.dirLibrary, this.platform,'include')
    #'-I' + path.resolve(dirLibrary,platform,'include','SDL2')
    '-I' + path.resolve( this.dirSource )
    '-I' + path.resolve( this.dirGeneratedSourceOutput )
    '-I' + path.resolve( this.dirSource,'angelscript')
    '-I' + path.resolve( this.dirSource,'component')
    '-I/usr/local/include'
    '-I/usr/include'
  ]
  this.linkerDirectories = [
    '-L' + path.resolve( this.dirLibrary, this.platform )
    '-L' + path.resolve( this.dirLibrary, this.platform, 'lib' )
    '-L/usr/local/lib'
    '-L/usr/lib'
  ]

  # config CSON (only values, no expressions)
  this.mustache = {
    sourceGlob: '*.mustache'
    rename: { extname: ''}
    context: { Components: [] }
  }
  # project config is merged with target
  this.project = {
    outputExecutableName: 'default'
    compilerDefines: [
      '-g'
      '-x c++'
      '-std=c++11'
      # '-DCONFIG_DEBUG'
      # '-DGL_GLEXT_PROTOTYPES'
    ]
    LinkerArgs: [
      # '-lstdc++'
      # '-lm'
      # '-lpthread'
    ]
    sourceGlob: '**/*.cpp'
    watchGlob: '{**/*.cpp,**/*.h,**/*.mustache}'
    assetGlob: '**/*@(.png|.ogg|.json|.as|.frag|.vert)'
  }
  this.target = {
    linux: {
      compilerDefines: []
      LinkerArgs: [
          # '-lstdc++'
          # '-lm'
          # '-lpthread'
          # '-lSDL2main'
          # '-lSDL2'
          # '-lSDL2_image'
          # '-langelscript'
          # '-lGL'
          # '-lphysfs'
      ]
    }
    darwin:{
      compilerDefines: []
      LinkerArgs:[
        # '-lstdc++'
        # '-lm'
        # '-liconv'
        # '-lpthread'
        # '-lSDL2main'
        # '-lSDL2'
        # #'-lSDL2_image'
        # '-langelscript'
        # '-lphysfs'
      ]
      Frameworks:[
        # '-framework CoreVideo'
        # '-framework GLKit'
        # '-framework OpenGL'
        # '-framework IOKit' # physfs
        # '-framework ForceFeedback'
        # '-framework Cocoa'
        # '-framework Carbon' # physfs
        # '-framework CoreAudio'
        # '-framework AudioToolbox'
        # '-framework AudioUnit'
      ]
    }

  }

  return this # be sure to return an object
