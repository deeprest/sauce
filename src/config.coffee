os = require 'os'
path = require 'path'

module.exports = ->
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
  this.outputExecutableName = 'defaultExecutableName'
  this.compilerDefines = [ '-DCONFIG_DEBUG', '-DGL_GLEXT_PROTOTYPES'] #'-DAS_USE_NAMESPACE' ]
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
  this.sourceGlob = '**/*.cpp'
  this.watchGlob = '{**/*.cpp,**/*.h,**/*.mustache}'
  this.assetGlob = '**/*@(.png|.ogg|.json|.as|.frag|.vert)'

  this.mustache = {
    sourceGlob: '*.mustache'
    rename: { extname: ''}
    context: { Components: [] }
  }
  # this.templatefilename = '*.mustache'
  # this.rename = { extname: ''}
  # this.context = { Components: [] }
  return this # be sure to return an object
