os = require 'os'
path = require 'path'
fs = require 'fs'
exec = (require 'child_process').exec
spawn = (require 'child_process').spawn

gulp = require 'gulp'
rename = require "gulp-rename"
mustache = require "gulp-mustache"
watch = require 'gulp-watch'
gulpcson = require 'gulp-cson'
print = require 'gulp-print'
run = require 'gulp-run'
repl = require 'gulp-repl'
changed = require 'gulp-changed'
newer = require 'gulp-newer'
cache = require 'gulp-cached'
remember = require 'gulp-remember'

yargs = require('yargs').argv
cson = require 'cson'
glob = require 'glob'
merge = require 'deepmerge'
request = require 'request'
tar = require 'tar'

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
      console.log 'exists: '+currentPath

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


ConfigObject = ()->
  this.devPlatform = os.platform()
  this.targetPlatform = this.devPlatform
  this.dirRoot = path.resolve process.cwd(), '..', '..'
  this.dirSource = path.resolve this.dirRoot, 'code'
  this.dirGeneratedSourceOutput = path.resolve this.dirSource, 'mustached'
  this.dirDownload = path.resolve this.dirRoot, 'external'
  this.dirExternal = path.resolve this.dirRoot, 'external', this.targetPlatform
  this.dirBuildRoot = path.resolve this.dirRoot, 'dev-build'
  this.dirCache = path.resolve this.dirBuildRoot, '.cache'
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
    ]
    external: []
    linkerArgs: []
    sourceGlob: '**/*.cpp'
    watchGlob: '{**/*.cpp,**/*.h,**/*.mustache}'
    assetGlob: '**/*@(.png|.ogg|.json|.as|.frag|.vert)'
  }
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
  return this # be sure to return an object

config = new ConfigObject

Configure = (done)->
  if yargs.config == undefined
    yargs.config = 'example.cson'
  console.log 'Configuring from file: '+yargs.config
  buffer = ''
  rs = fs.createReadStream yargs.config, {flags:'r',encoding:'utf8'}
  rs.on 'error', (err)->  console.log 'error: '+err
  rs.on 'data', (chunk) ->  buffer += chunk
  rs.on 'end', ->
    obj = cson.parse buffer
    config = merge config, obj
    target = undefined
    switch config.targetPlatform
      when 'linux' then target = config.target.linux; break
      when 'darwin' then target = config.target.darwin; break
      else console.log( 'platform '+ config.targetPlatform +'not supported by build script!')
    config.project = merge config.project, target
    # add lowercase names to mustahce component list
    for component in config.mustache.context.Components
      component['lowerName'] = component.type.toLowerCase()
    # console.log config
    console.log 'Configured for platform: ' + config.targetPlatform
    done()

Start = (done)->
  gulp.repl = repl.start gulp
  done()

Download = (url,filepath)->
  return new Promise (resolve, reject)->
    console.log 'Downloading '+url
    request.get url
    .on 'response', (rsp)->
      if rsp.statusCode == 404
        reject('Bad URL:'+url)
    .on 'error', (err)->
      reject('Error connecting to url: '+err)
    .pipe fs.createWriteStream path.resolve( config.dirDownload, filepath )
      .on 'finish', ()->
        console.log 'Finished downloading to '+filepath
        resolve()
      .on 'error', (err)->
        reject('Error writing file: '+err)

box2d = ()->
  # return Download('https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1','box2d.tar.gz')
  return (new Promise (resolve,reject) -> resolve())
  .then ()-> return tar.extract {file:path.resolve(config.dirDownload,'box2d.tar.gz'),cwd:config.dirDownload }, (err, stdout, stderr) -> console.log 'tar extract done'
  .then ()-> return new Promise (resolve,reject) ->
    exec 'cmake -G "Unix Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
      if err then reject( 'cmake failed: '+err ); return
      exec 'cp -r Box2D '+path.resolve(config.dirExternal,'include'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D')}, (err, stdout, stderr) ->
        if err then reject( 'cp failed: '+err ); return
        exec 'make config="debug"', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
          if err then reject( 'make config failed: '+err ); return
          exec 'cp libBox2D.a '+path.resolve(config.dirExternal,'lib'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build','Box2D')}, (err, stdout, stderr) ->
            if err then reject( 'cp failed: '+err ); return
            resolve()
            # TODO: clean up?
  .catch (reason)-> console.error reason

sdl_build = ()->
  SDL='SDL-2.0.4-10002'
  # return Download('https://www.libsdl.org/tmp/'+SDL+'.tar.gz',SDL+'.tar.gz')
  # .then ()-> return tar.extract {file:path.resolve(config.dirDownload,SDL+'.tar.gz'),cwd:config.dirDownload }, (err, stdout, stderr) -> console.log 'tar extract done'
  return new Promise (resolve,reject) ->
  # .then ()-> return new Promise (resolve,reject) ->
    buildDir = path.resolve(config.dirDownload,SDL,'build-'+config.targetPlatform)
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
sdl = ()->
  return new Promise (resolve,reject) ->
    resolve()
glm = ()->
  return new Promise (resolve,reject) ->
    resolve()
json = ()->
  return new Promise (resolve,reject) ->
    resolve()
mojosetup = ()->
  return new Promise (resolve,reject) ->
    resolve()
angelscript = ()->
  return new Promise (resolve,reject) ->
    resolve()

Setup = ()->
  ray = []
  return new Promise (resolve, reject)->
    for ekey,evalue of config.project.external
      console.log evalue
      switch evalue
        when 'sdl' then ray.push sdl; break
        when 'sdl-build' then ray.push sdl_build; break
        when 'box2d' then ray.push box2d; break
        when 'glm' then ray.push glm; break
        when 'json' then ray.push json; break
        when 'angelscript' then break
        when 'mojosetup' then break
        else console.log 'Unknown external '+evalue
    console.log 'done processing ext'
    resolve()
  .then gulp.series ray

Clean = (done)->
  if fs.existsSync config.dirObj
    rmdirSync config.dirObj
  if fs.existsSync config.dirCache
    rmdirSync config.dirCache
  fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName), ->{}
  if config.targetPlatform=='darwin'
    fs.stat path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err,stats)->
      fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err)->
        done()
  else done()

Assets = (done)->
  return gulp.src config.project.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false }
  .pipe cache 'assets'
  .pipe print( (filepath)=> return 'Asset copied: '+filepath )
  .pipe gulp.dest( config.dirOutput )
  .on 'finish', ()-> done()

CSON = (done)->
  return gulp.src '**/*.cson', {cwd:path.resolve(config.dirAsset), ignoreInitial:false }
  .pipe cache 'cson'
  .pipe gulpcson()
  .pipe print( (filepath)=> return 'CSON=>JSON: '+filepath )
  .pipe gulp.dest( config.dirOutput )
  .on 'finish', ()-> done()

Mustache = (done)->
  return gulp.src config.mustache.sourceGlob, {cwd:path.resolve(config.dirSource), ignoreInitial:false }
  .pipe cache 'mustache'
  .pipe mustache( config.mustache.context )
  .pipe rename( config.mustache.rename )
  .pipe print (filepath)=> return 'Mustaching: '+filepath
  .pipe gulp.dest( config.dirGeneratedSourceOutput )
  .on 'finish', ()-> done()

watcher = (done)->
  gulp.watch config.mustache.sourceGlob, Mustache
  gulp.watch path.resolve( config.dirAsset, '**/*.cson'), CSON
  gulp.watch config.project.assetGlob, Mustache

CompileAll = ()->
  return new Promise (resolve, reject)->
    if fs.existsSync(config.dirObj) == false
      mkdirSync config.dirObj
    sourceFiles = glob.sync path.resolve(config.dirSource,config.project.sourceGlob)
    externalSourceFiles = glob.sync path.resolve(config.dirExternal,'src', config.project.sourceGlob)
    sourceFiles.push externalSourceFiles.join(' ')
    comp = [] #['-g','-x c++','-std=c++11']
    comp.push config.project.compilerDefines.join(' ')
    comp.push config.includeDirectories.join(' ')
    total = sourceFiles.length
    count = total
    for f in sourceFiles
      console.log 'sourcefile: '+f
      relpath = ''
      if f.indexOf(config.dirSource)>=0
        relpath = path.relative config.dirSource, f
      if f.indexOf(config.dirExternal)>=0
        relpath = path.relative config.dirExternal, f
      if relpath.length == 0
        count--;
        continue
      dir = path.dirname( path.resolve(config.dirObj, relpath ))
      if fs.existsSync( dir)== false
        mkdirSync dir
      finalPath = path.resolve( config.dirObj, path.dirname(relpath), path.basename(relpath,'.cpp')+'.o')
      console.log 'finalPath: '+finalPath

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
  sourceGlobs = [ path.resolve(config.dirSource,config.project.sourceGlob), path.resolve(config.dirExternal,'src', config.project.sourceGlob) ]
  return gulp.src sourceGlobs
  .pipe rename { extname:'.cache' }
  .pipe cache 'source'

CompileIncremental = (done)->
  comp = [] #['-g','-x c++','-std=c++11']
  comp.push config.project.compilerDefines.join(' ')
  comp.push config.includeDirectories.join(' ')
  command = 'clang++ -x c++ -g -c - -o - '+comp.join(' ')
  sourceGlobs = [path.resolve(config.dirSource,config.project.sourceGlob), path.resolve(config.dirExternal,'src', config.project.sourceGlob) ]
  return gulp.src sourceGlobs
  .pipe rename { extname:'.cache' }
  .pipe cache 'source' #, {optimizeMemory:true}
  .pipe print (filepath)-> return 'changed: '+filepath
  # .pipe gulp.dest config.dirCache #no reason to write out the cache without a read somewhere
  .pipe run( command, {silent:true})
  .pipe rename { extname: '.o'}
  .pipe print (filepath)-> return 'compiled: '+filepath
  .pipe gulp.dest config.dirObj

Link = (done)->
  link = []
  linkerArgs = config.project.linkerArgs
  linkerArgs.push config.linkerDirectories
  link.push '-Wl,' + linkerArgs.join(',')
  if config.targetPlatform == 'darwin'
    link.push config.project.frameworks.join(' ')
  objectFiles = glob.sync config.dirObj+'/**/*.o'
  linkCommand = ['clang++ -g', objectFiles.join(' '), link.join(' '),  '-o', path.resolve( config.dirOutput, config.project.outputExecutableName) ].join(' ')
  # console.log linkCommand
  exec linkCommand, (err, stdout, stderr) ->
    console.log stdout
    console.log stderr
    if err then console.error 'LINK ERROR: '+err
    else if config.targetPlatform == 'darwin'
      exec 'dsymutil -o '+path.resolve(config.dirOutput, config.project.outputExecutableName)+'.dSYM '+path.resolve(config.dirOutput, config.project.outputExecutableName),
      {maxBuffer: 1024 * 1024},
      (err, stdout, stderr) ->
        if err then console.error err
    done()

Launch = (done)->
  app = spawn path.resolve(config.dirOutput, config.project.outputExecutableName), [], {stdio:'inherit'}
  app.on 'close', (code) ->
    console.log 'child process exited with code '+code
    done()

Prebuild = gulp.parallel Mustache, CSON, Assets
Build = gulp.series Prebuild, CompileAll, Link

gulp.task 'default', gulp.series Configure, Start, watcher
gulp.task 'config', Configure
gulp.task 'setup', Setup
gulp.task 'watch', watcher
gulp.task 'clean', Clean
gulp.task 'link', Link
gulp.task 'rebuild', gulp.series Clean, Prebuild, PrimeCache, CompileAll, Link
gulp.task 'build', gulp.series Prebuild, CompileIncremental, Link
gulp.task 'launch', gulp.series gulp.parallel(CSON, Assets), Launch
