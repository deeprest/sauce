os = require 'os'
path = require 'path'

module.exports = ()->
  this.devPlatform = os.platform()
  this.targetPlatform = this.devPlatform
  this.dirRoot = path.resolve process.cwd(), '..', '..'
  this.dirSource = path.resolve this.dirRoot, 'code'
  this.dirGeneratedSourceOutput = path.resolve this.dirSource, 'mustached'
  this.dirDownload = path.resolve this.dirRoot, 'external'
  this.dirExternal = path.resolve this.dirRoot, 'external', this.targetPlatform
  this.dirBuildRoot = path.resolve this.dirRoot, 'dev-build'
  this.dirOutput = path.resolve this.dirBuildRoot, this.targetPlatform
  this.dirObj = path.resolve this.dirBuildRoot, '.obj'
  this.dirTool = path.resolve this.dirRoot, 'tool'
  this.dirAsset = path.resolve this.dirRoot, 'asset'
  this.includeDirectories = [
    '-I' + path.resolve this.dirExternal, 'include'
    '-I' + path.resolve this.dirSource
    '-I' + path.resolve this.dirGeneratedSourceOutput
    '-I' + path.resolve this.dirSource,'angelscript'
    '-I' + path.resolve this.dirSource,'component'
    '-I/usr/local/include'
    '-I/usr/include'
  ]
  this.linkerDirectories = [
    '-L' + path.resolve this.dirExternal
    '-L' + path.resolve this.dirExternal, 'lib'
    '-L/usr/local/lib'
    '-L/usr/lib'
  ]

  # config CSON (only values, no expressions)
  this.mustache = {
    sourceGlob: '*.mustache'
    rename: { extname: ''}
    context: { Components: [] }
  }

  this.project = {
    outputExecutableName: 'default'
    compilerDefines: [
      '-g'
      '-x c++'
      '-std=c++11'
      # '-DCONFIG_DEBUG'
      # '-DGL_GLEXT_PROTOTYPES'
    ]
    external: []
    linkerArgs: [
      # '-lstdc++'
      # '-lm'
      # '-lpthread'
    ]
    sourceGlob: '**/*.cpp'
    watchGlob: '{**/*.cpp,**/*.h,**/*.mustache}'
    assetGlob: '**/*@(.png|.ogg|.json|.as|.frag|.vert)'
  }

  # anything in the active target.[platform] object is merged into this.project
  this.target = {
    linux: {
      external: []
      compilerDefines: []
      linkerArgs: [
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
      external: []
      compilerDefines: []
      linkerArgs:[
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
      frameworks:[
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
