os = require 'os'
path = require 'path'
fs = require 'fs-extra'
exec = (require 'child_process').exec
spawn = (require 'child_process').spawn

gulp = require 'gulp'
rename = require "gulp-rename"
mustache = require "gulp-mustache"
watch = require 'gulp-watch'
gulpcson = require 'gulp-cson'
print = require 'gulp-print'
repl = require 'gulp-repl'
changed = require 'gulp-changed'
newer = require 'gulp-newer'
cache = require 'gulp-cached'
remember = require 'gulp-remember'
run = require 'gulp-run'
sourcemaps = require 'gulp-sourcemaps'

clang = require './gulpclang.js'

yargs = require('yargs').argv
cson = require 'cson'
glob = require 'glob'
merge = require 'deepmerge'
request = require 'request'
tar = require 'tar'
decompress = require 'decompress'


external = require './external.js'

mkdirSync = (dir) ->
  if dir.indexOf('/')==0
    dir = dir.substring(1)
  ray = dir.split('/')
  currentPath=''
  ray.forEach (element)->
    currentPath += '/'+element
    try
      fs.mkdirSync currentPath
    catch
      # console.log 'exists: '+currentPath

rmdirSync = (dirPath)->
  try
    files = fs.readdirSync dirPath
  catch
    return error
  if files.length > 0
    for i in files
      filePath = dirPath + '/' + i
      if fs.statSync(filePath).isFile()
        fs.unlinkSync filePath
      else
        rmdirSync filePath
  return fs.rmdirSync dirPath


Path = ()->
  Root : undefined
  Source : undefined
  GeneratedSourceOutput : undefined
  Download : undefined
  External : undefined
  BuildRoot : undefined
  Cache : undefined
  Output : undefined
  Obj : undefined
  Tool : undefined
  Asset : undefined


ConfigObject = ()->
  this.devPlatform = os.platform()
  this.targetPlatform = this.devPlatform
  this.path = new Path
  this.outputExecutableName = 'default'
  this.compilerDefines = [
    '-g'
    '-x c++'
    '-std=c++11'
  ]
  this.external = []
  this.linkerArgs = []
  this.sourceGlob = '**/*.cpp'
  this.watchGlob = '{**/*.cpp,**/*.h,**/*.mustache}'
  this.assetGlob = '**/*@(.png|.ogg|.json|.as|.frag|.vert)'
  this.sourceGlobs = []
  # anything in the active target.[platform] object is merged into this.project
  this.target = {
    linux: {
      external: []
      compilerDefines: []
      linkerArgs: []
    }
    darwin:{
      external: []
      compilerDefines: []
      linkerArgs:[]
      frameworks:[]
    }
  }
  this.mustache = {
    sourceGlob: '*.template'
    rename: { extname: '' }
    context: { Components: [] }
  }
  return this # be sure to return an object

config = null

Configure = (done)->
  config = new ConfigObject
  if yargs.config == undefined
    yargs.config = 'example.cson'
  console.log 'Configuring from file: '+yargs.config
  # read build.cson
  buffer = fs.readFileSync yargs.config, {flags:'r',encoding:'utf8'}
  configFile = cson.parse buffer

  # set defaults based on config file Root path
  config.path.Root = configFile.path.Root
  config.path.Source = path.resolve config.path.Root, 'code'
  config.path.GeneratedSourceOutput = path.resolve config.path.Source, 'mustached'
  config.path.Download = path.resolve config.path.Root, 'external', 'download'
  config.path.External = path.resolve config.path.Root, 'external', config.targetPlatform
  config.path.BuildRoot = path.resolve config.path.Root, 'dev-build'
  config.path.Cache = path.resolve config.path.BuildRoot, '.cache'
  config.path.Output = path.resolve config.path.BuildRoot, config.targetPlatform
  config.path.Obj = path.resolve config.path.BuildRoot, '.obj'
  config.path.Tool = path.resolve config.path.Root, 'tool'
  config.path.Asset = path.resolve config.path.Root, 'asset'

  config.includeDirectories = [
    path.resolve config.path.External, 'include'
    path.resolve config.path.Source
    path.resolve config.path.GeneratedSourceOutput
    path.resolve config.path.Source,'angelscript'
    path.resolve config.path.Source,'component'
    '/usr/local/include'
    '/usr/include'
  ]
  config.linkerDirectories = [
    path.resolve config.path.External
    path.resolve config.path.External, 'lib'
    '/usr/local/lib'
    '/usr/lib'
  ]

  # overwrite the default config values
  config = merge config, configFile

  # merge target specific values
  target = undefined
  switch config.targetPlatform
    when 'linux' then target = config.target.linux; break
    when 'darwin' then target = config.target.darwin; break
    else console.log( 'platform '+ config.targetPlatform +'not supported by build script!')
  config = merge config, target

  # add lowercase names to mustache component list
  for component in config.mustache.context.Components
    component['lowerName'] = component.type.toLowerCase()

  config.sourceGlobs.push path.resolve( config.path.Source, config.sourceGlob )
  #config.sourceGlobs.push path.resolve( config.path.External, config.sourceGlob )

  # keep roots for .o file paths
  config.pathroots = []
  # assign pathroots for .o files in compiled object dir
  for k,v of config.path
    if k != 'root'
      if v?
        if path.isAbsolute v
          # config.sourceGlobs.push path.resolve( v, config.sourceGlob )
          config.pathroots.push v
        else
          console.log 'relative: '+v
          # config.sourceGlobs.push path.resolve( config.path.root, v, config.sourceGlob )
          config.pathroots.push path.resolve( config.path.root, v)

  # console.log config
  console.log 'Configured for target platform: ' + config.targetPlatform
  # define the external library setup task based on config.external
  if config.external.length > 0
    gulp.task 'setup', gulp.series config.external
  fs.mkdirsSync path.resolve(config.path.External)
  fs.mkdirsSync path.resolve(config.path.Download)
  done()


Start = (done)->
  gulp.repl = repl.start gulp
  done()

Download = (url,filepath)->
  return new Promise (resolve, reject)->
    # fs.mkdirs path.resolve( config.path.Download ), (err) ->
    #   if err then reject( 'create dir failed: '+err ); return
    console.log 'Downloading '+url
    request.get url
    .on 'response', (rsp)->
      if rsp.statusCode == 404
        reject('Bad URL:'+url)
    .on 'error', (err)->
      reject('Error connecting to url: '+err)
    .pipe fs.createWriteStream path.resolve( config.path.Download, filepath )
      .on 'finish', ()->
        console.log 'Finished downloading to '+filepath
        resolve()
      .on 'error', (err)->
        reject('Error downloading file: '+err)

box2d = ()->
  version='2.3.1'
  return Download('https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1','box2d.tar.gz')
  .then ()-> return tar.extract {file:path.resolve(config.path.Download,'box2d.tar.gz'),cwd:config.path.Download }, (err, stdout, stderr) -> console.log 'tar extract done'
  .then ()-> return new Promise (resolve,reject) ->
    console.log 'building box2d...'
    exec 'cmake -G "Unix Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..', {cwd:path.resolve(config.path.Download,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
      if err then reject( 'cmake failed: '+err ); return
      fs.copySync path.resolve(config.path.Download,'Box2D-2.3.1','Box2D','Box2D'), path.resolve(config.path.External,'include','Box2D')
      exec 'make config="debug"', {cwd:path.resolve(config.path.Download,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
        if err then reject( 'make config failed: '+err ); return
        fs.copySync path.resolve(config.path.Download,'Box2D-2.3.1','Box2D','Build','Box2D','libBox2D.a'), path.resolve(config.path.External,'lib','libBox2D.a')
        #fs.removeSync path.resolve(config.path.Download,'Box2D-2.3.1')
        resolve()
  .catch (reason)-> console.error reason
# register task
gulp.task 'box2d', box2d

###
sdl_build = ()->
  SDL='SDL-2.0.4-10002'
  # return Download('https://www.libsdl.org/tmp/'+SDL+'.tar.gz',SDL+'.tar.gz')
  # .then ()-> return tar.extract {file:path.resolve(config.path.Download,SDL+'.tar.gz'),cwd:config.path.Download }, (err, stdout, stderr) -> console.log 'tar extract done'
  return new Promise (resolve,reject) ->
  # .then ()-> return new Promise (resolve,reject) ->
    buildDir = path.resolve(config.path.Download,SDL,'build-'+config.targetPlatform)
    fs.mkdir buildDir, (err)->
      #if err then reject(err); return
      switch config.targetPlatform
        when 'linux'
          #'../configure --prefix=$DIR_LIB; make clean; make; make install'
          break
        when 'darwin'
          #; make clean; make
          spawn '../configure', {shell:true,cwd:buildDir,env:{'CC':path.resolve(SDL,'build-scripts/gcc-fat.sh')}}, (err, stdout, stderr) ->
            if err then reject( 'sdl build failed: '+err ); return
            spawn 'make clean; make', {shell:true,cwd:buildDir}, (err, stdout, stderr) ->
              if err then reject( 'sdl build failed: '+err ); return
              resolve()
          break
        else
          console.log "target platform "+ config.targetPlatform +"not supported by build script!"
    # clean
    #   #cp build/.libs/libSDL2.a ../../$SYSTEM
    #   #cp include/* ../../$SYSTEM/include
    #   #cp ../include/* ../../$SYSTEM/include
###

glm = ()->
  version = '0.9.8.4'
  zipFile='glm-'+version+'.zip'
  return Download('https://github.com/g-truc/glm/archive/'+version+'.zip', zipFile )
  .then ()-> decompress path.resolve(config.path.Download,zipFile), config.path.Download
  .then ()-> return new Promise (resolve,reject) ->
    fs.copySync path.resolve(config.path.Download,'glm-'+version+'/glm'), path.resolve(config.path.External,'include','glm')
    fs.removeSync path.resolve(config.path.Download,'glm-'+version)
    fs.removeSync path.resolve(config.path.Download,zipFile)
    resolve()
# register task
gulp.task 'glm', glm

json = ()->
  version='3.1.2'
  return Download( 'https://github.com/nlohmann/json/releases/download/v'+version+'/json.hpp', "json.hpp" )
  .then ()-> fs.copy( path.resolve(config.path.Download,'json.hpp'), path.resolve(config.path.External,'include','json.hpp') )
# register task
gulp.task 'json', json

# TODO
angelscript = ()->
  return new Promise (resolve,reject) ->
    resolve()
# register task
gulp.task 'angelscript', angelscript

physfs = ()->
  return Download 'https://hg.icculus.org/icculus/physfs/archive/tip.tar.gz', 'physfs.tar.gz'
  .then ()-> decompress path.resolve(config.path.Download,'physfs.tar.gz'), path.resolve(config.path.Download,'physfs'), {strip:1}
  .then ()-> new Promise (resolve,reject) ->
    # fs.removeSync path.resolve(config.path.Download,'physfs.tar.gz')
    fs.mkdirsSync path.resolve(config.path.Download,'physfs','build')
    cmakeCommand = 'cmake -DPHYSFS_ARCHIVE_ZIP=false -DPHYSFS_ARCHIVE_WAD=false -DPHYSFS_ARCHIVE_QPAK=false -DPHYSFS_ARCHIVE_MVL=false -DPHYSFS_ARCHIVE_HOG=false -DPHYSFS_HAVE_CDROM_SUPPORT=false -DPHYSFS_BUILD_TEST=false -DPHYSFS_BUILD_STATIC=true -DPHYSFS_BUILD_SHARED=false -DPHYSFS_ARCHIVE_7Z=false ..'
    exec cmakeCommand, {cwd:path.resolve(config.path.Download,'physfs', 'build')}, (err, stdout, stderr) ->
      if err then reject( 'cmake failed: '+err ); return
      exec 'make', {cwd:path.resolve(config.path.Download,'physfs', 'build')}, (err, stdout, stderr) ->
        if err then reject( 'cmake failed: '+err ); return
        fs.copySync path.resolve(config.path.Download,'physfs', 'build','libphysfs.a'), path.resolve(config.path.External,'lib','libphysfs.a')
        fs.copySync path.resolve(config.path.Download,'physfs','src','physfs.h'), path.resolve(config.path.External,'include','physfs.h')
        # fs.removeSync path.resolve(config.path.Download,'physfs')
        resolve()
# register task
gulp.task 'physfs', physfs

Clean = (done)->
  if fs.existsSync config.path.Obj
    rmdirSync config.path.Obj
  if fs.existsSync config.path.Cache
    rmdirSync config.path.Cache
  fs.unlink path.resolve(config.path.Output, config.outputExecutableName), ->{}
  if config.targetPlatform=='darwin'
    fs.stat path.resolve(config.path.Output, config.outputExecutableName+'.dSYM'), (err,stats)->
      fs.unlink path.resolve(config.path.Output, config.outputExecutableName+'.dSYM'), (err)->
        done()
  else done()

Assets = (done)->
  return gulp.src config.assetGlob, {cwd:path.resolve(config.path.Asset), ignoreInitial:false }
  .pipe cache 'assets'
  .pipe print( (filepath)=> return 'Asset copied: '+filepath )
  .pipe gulp.dest( config.path.Output )
  .on 'finish', ()-> done()

CSON = (done)->
  return gulp.src '**/*.cson', {cwd:path.resolve(config.path.Asset), ignoreInitial:false }
  .pipe cache 'cson'
  .pipe gulpcson()
  .pipe print( (filepath)=> return 'CSON=>JSON: '+filepath )
  .pipe gulp.dest( config.path.Output )
  .on 'finish', ()-> done()

Mustache = (done)->
  return gulp.src config.mustache.sourceGlob, {cwd:path.resolve(config.path.Source), ignoreInitial:false }
  .pipe cache 'mustache'
  .pipe mustache( config.mustache.context )
  .pipe rename( config.mustache.rename )
  .pipe print( (filepath)=> return 'Mustaching: '+filepath )
  .pipe gulp.dest( config.path.GeneratedSourceOutput )
  .on 'finish', ()-> done()

watcher = (done)->
  gulp.watch path.resolve( config.path.Source, config.mustache.sourceGlob ), Mustache
  gulp.watch path.resolve( config.path.Asset, '**/*.cson'), CSON
  gulp.watch path.resolve( config.path.Asset, config.assetGlob ), Assets

CompileAll = ()->
  return new Promise (resolve, reject)->
    if fs.existsSync(config.path.Obj) == false
      mkdirSync config.path.Obj
    sourceFiles = []
    for sf in config.sourceGlobs
      sourceFiles = sourceFiles.concat glob.sync(sf)
    console.log 'SOURCEFILES:'
    console.log sourceFiles

    comp = [] #['-g','-x c++','-std=c++11']
    comp.push config.compilerDefines.join(' ')
    includeDirs = config.includeDirectories.map (x) -> return '-I'+x
    comp.push includeDirs.join(' ')

    total = sourceFiles.length
    count = total
    for f in sourceFiles
      # console.log 'sourcefile: '+f
      relpath = f
      for k,v of config.pathroots
        if f.indexOf(v)>=0
          relpath = path.relative v, f
          break
      if relpath.length == 0
        count--;
        continue
      dir = path.dirname( path.resolve(config.path.Obj, relpath ))
      if fs.existsSync( dir)== false
        mkdirSync dir
      finalPath = path.resolve( config.path.Obj, path.dirname(relpath), path.basename(relpath,'.cpp')+'.o')
      # console.log 'finalPath: '+finalPath
      command = 'clang++ -g -c -o '+finalPath+' '+f+' '+comp.join(' ')
      exec command, {maxBuffer: 1024 * 1024}, (err, stdout, stderr) ->
        if stdout.length > 0
          console.log 'STDOUT '+stdout
          if stdout.indexOf('error:') >= 0
            count = 0
            reject( new Error('stdout') )
            return
        if stderr.length > 0
          console.log 'STDERROR '+stderr
          if stderr.indexOf('error:')>=0
            count = 0
            reject( new Error('stderr') )
            return
        count--;
        if count <= 0
          resolve()
          return
        console.log parseInt( 100*(1-count/total) ).toString()+'%'


PrimeCache = ()->
  return gulp.src config.sourceGlobs
  # .pipe rename { extname:'.cache' }
  .pipe cache 'source'

CompileIncremental = (done)->
  comp = [] #['-g','-x c++','-std=c++11']
  comp.push config.compilerDefines.join(' ')

  includeDirs = config.includeDirectories.map (x) -> return '-I'+x
  comp.push includeDirs.join(' ')

  command = 'clang++ -x c++ -g -c - -o - '+comp.join(' ')
  return gulp.src config.sourceGlobs
  .pipe cache 'source' #, {optimizeMemory:true}
  .pipe print (filepath)-> return 'changed: '+filepath
  # .pipe gulp.dest config.path.Cache #no reason to write out the cache without a read somewhere
  .pipe run( command, {silent:true})
  .pipe rename { extname: '.o'}
  .pipe print (filepath)-> return 'compiled: '+filepath
  .pipe gulp.dest config.path.Obj

Link = (done)->
  link = []
  linkerArgs = config.linkerArgs.slice()

  linkerDirs = config.linkerDirectories.map (x) -> return '-L'+x
  linkerArgs.push linkerDirs

  link.push '-Wl,' + linkerArgs.join(',')
  if config.targetPlatform == 'darwin'
    link.push config.frameworks.join(' ')
  objectFiles = glob.sync config.path.Obj+'/**/*.o'
  linkCommand = ['clang++ -g', objectFiles.join(' '), link.join(' '),  '-o', path.resolve( config.path.Output, config.outputExecutableName) ].join(' ')
  # console.log linkCommand
  exec linkCommand, (err, stdout, stderr) ->
    console.log stdout
    console.log stderr
    if err then console.error 'LINK ERROR: '+err
    else if config.targetPlatform == 'darwin'
      exec 'dsymutil -o '+path.resolve(config.path.Output, config.outputExecutableName)+'.dSYM '+path.resolve(config.path.Output, config.outputExecutableName),
      {maxBuffer: 1024 * 1024},
      (err, stdout, stderr) ->
        if err then console.error err
    done()

Launch = (done)->
  app = spawn path.resolve(config.path.Output, config.outputExecutableName), [], {cwd:config.path.Output, stdio:'inherit'}
  app.on 'close', (code) ->
    console.log 'child process exited with code '+code
    done()

Prebuild = gulp.parallel Mustache, CSON, Assets
Build = gulp.series Prebuild, CompileAll, Link

gulp.task 'default', gulp.series Configure, Start #, watcher
gulp.task 'config', Configure
# setup is defined in Configure so libraries can be added easily to config file
# gulp.task 'setup', Setup
gulp.task 'watch', watcher
gulp.task 'clean', Clean
gulp.task 'link', Link
gulp.task 'rebuild', gulp.series Clean, Prebuild, PrimeCache, CompileAll, Link
gulp.task 'build', gulp.series Prebuild, CompileIncremental, Link
gulp.task 'launch', gulp.series gulp.parallel(CSON, Assets), Launch
