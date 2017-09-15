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
git = require 'gulp-git'

# apt = require 'apt'
yargs = require('yargs').argv
cson = require 'cson'
glob = require 'glob'
merge = require 'deepmerge'
request = require 'request'
tar = require 'tar'
fse = require 'fs-extra'

stream = require 'stream' # TEMP

config = (require './config.js')()
external = require './external.js'
# external.config = config


Start = (done)->
  gulp.repl = repl.start gulp
  done()

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
      else console.log "platform "+ config,platform +"not supported by build script!"
    config.project = merge config.project, target
    # add lowercase names to mustahce component list
    for component in config.mustache.context.Components
      component['lowerName'] = component.type.toLowerCase()
    # console.log config
    console.log 'Configured for platform: ' + config.targetPlatform
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

angelscript = ()->
  return new Promise (resolve,reject) ->
    resolve()

lua = ()->
  luaVersion = 'lua-5.3.4'
  return new Promise (resolve,reject) ->
    # exec 'curl -R -O http://www.lua.org/ftp/'+luaVersion+'.tar.gz', {cwd:path.resolve(config.dirDownload)}, (err, stdout, stderr) ->
    #   if err then reject( err ); return
    #   exec 'tar zxf '+luaVersion+'.tar.gz', {cwd:path.resolve(config.dirDownload)}, (err, stdout, stderr) ->
    #     if err then reject( err ); return
    #     makeCommand = ''
    #     if config.targetPlatform == 'linux' then makeCommand = 'make linux test'
    #     if config.targetPlatform == 'darwin' then makeCommand = 'make macosx test'
    #     exec makeCommand, {cwd:path.resolve(config.dirDownload,luaVersion)}, (err, stdout, stderr) ->
    #       if err then reject( err ); return
          fs.copyFile path.resolve(config.dirDownload,luaVersion,'src', 'liblua.a'), path.resolve(config.dirExternal,'lib','liblua.a'), (err)->
            if err then reject( err ); return
            resolve()

bullet3 = ()->
  return new Promise (resolve,reject)->
    git.clone 'https://github.com/bulletphysics/bullet3.git', {args:path.resolve(config.dirDownload,'bullet3')}, (err)->
      if err then reject(err); return
      exec './build_cmake_pybullet_double.sh', {cwd:path.resolve(config.dirDownload,'bullet3')}, (err, stdout, stderr) ->
        if err then reject( 'ERR: build failed: '+err ); return
        if stderr then reject( 'STDERR: build failed: '+stderr ); return
        console.log stdout
        resolve()

box2d = ()->
  # return Download('https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1','box2d.tar.gz')
  return (new Promise (resolve,reject) -> resolve())
  .then ()-> return tar.extract {file:path.resolve(config.dirDownload,'box2d.tar.gz'),cwd:config.dirDownload }, (err, stdout, stderr) -> console.log 'tar extract done'
  .then ()-> return new Promise (resolve,reject) ->
    exec 'cmake -G "Unix Makefiles" -DBOX2D_INSTALL=OFF -DBOX2D_BUILD_SHARED=OFF -DBOX2D_BUILD_EXAMPLES=OFF ..', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
      if err then reject( 'cmake failed: '+err ); return
      fs.copyFile path.resolve(config.dirDownload,luaVersion,'src', 'liblua.a'), path.resolve(config.dirExternal,'lib','liblua.a'), (err)->
        if err then reject( err ); return
      exec 'cp -r Box2D '+path.resolve(config.dirExternal,'include'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D')}, (err, stdout, stderr) ->
        if err then reject( 'cp failed: '+err ); return
        exec 'make config="debug"', {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build')}, (err, stdout, stderr) ->
          if err then reject( 'make config failed: '+err ); return
          exec 'cp libBox2D.a '+path.resolve(config.dirExternal,'lib'), {cwd:path.resolve(config.dirDownload,'Box2D-2.3.1','Box2D','Build','Box2D')}, (err, stdout, stderr) ->
            if err then reject( 'cp failed: '+err ); return
            resolve()
            # TODO: clean up?
  .catch (reason)-> console.error reason

sdl = ()->
  return new Promise (resolve,reject) ->
    if config.targetPlatform == 'darwin'
      exec 'brew install sdl', (err,stdout,stderr)->
        if err then reject(err); return;
    resolve()

sdl_build = ()->
  SDL_ARCHIVE='SDL-2.0.4-10002'
  return Download( 'https://www.libsdl.org/tmp/'+SDL_ARCHIVE+'.tar.gz', path.resolve(config.dirDownload,SDL_ARCHIVE+'.tar.gz') )
  .then ()-> return tar.extract {file:path.resolve(config.dirDownload,SDL_ARCHIVE+'.tar.gz'),cwd:config.dirDownload}, (err, stdout, stderr) -> console.log 'tar extract done'
  .then ()-> return new Promise (resolve,reject) ->
    # rm $SYSTEM/libSDL*
    # pushd $SDL_ARCHIVE
    #   mkdir build-$SYSTEM
    #   cd build-$SYSTEM
    #   if [[ "$SYSTEM" == "darwin" ]]; then
    #     CC=$(pwd)/../build-scripts/gcc-fat.sh ../configure
    #     make clean
    #     make
    #   else
    #     ../configure --prefix=$DIR_LIB
    #     make clean
    #     make
    #     make install
    #   fi
    #   ##cp build/lib* ../../$SYSTEM
    #   #cp build/.libs/libSDL2.a ../../$SYSTEM
    #   #cp include/* ../../$SYSTEM/include
    #   #cp ../include/* ../../$SYSTEM/include
    # popd
    resolve()
  .catch (reason)-> console.error reason

glm = ()->
  return new Promise (resolve,reject) ->
    resolve()
json = ()->
  return new Promise (resolve,reject) ->
    resolve()
mojosetup = ()->
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
        when 'bullet3' then ray.push bullet3; break
        when 'lua' then ray.push lua; break
        when 'angelscript' then break
        when 'mojosetup' then break
        else console.log 'Unknown external '+evalue
    console.log 'done processing ext'
    resolve()
  .then gulp.series ray

Clean = (done)->
  if fse.pathExistsSync config.dirObj
    fse.removeSync config.dirObj
  fse.removeSync path.resolve(config.dirOutput, config.project.outputExecutableName)
  if config.targetPlatform=='darwin'
    if fse.pathExistsSync path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM')
      fse.removeSync path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM')
  done()

Assets = (done)->
  gulp.src config.project.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false }
  .pipe print( (filepath)=> return 'Asset copied: '+filepath )
  .pipe gulp.dest( config.dirOutput )
  .on 'finish', ()-> done()

CSON = (done)->
  gulp.src '**/*.cson', {cwd:path.resolve(config.dirAsset), ignoreInitial:false }
  .pipe gulpcson()
  .pipe print( (filepath)=> return 'CSON=>JSON: '+filepath )
  .pipe gulp.dest( config.dirOutput )
  .on 'finish', ()-> done()

Mustache = (done)->
  gulp.src config.mustache.sourceGlob, {cwd:path.resolve(config.dirSource)}
  .pipe mustache( config.mustache.context )
  .pipe rename( config.mustache.rename )
  .pipe print (filepath)=> return 'Mustaching: '+filepath
  .pipe gulp.dest( config.dirGeneratedSourceOutput )
  .on 'finish', ()-> done()

watcher = (done)->
  gulp.watch config.mustache.sourceGlob, Mustache
  gulp.watch path.resolve(config.dirAsset,'**/*.cson'), CSON
  gulp.watch config.project.assetGlob, Mustache

CompileAll = (done)->
  return new Promise (resolve, reject)->
    if fs.existsSync(config.dirObj) == false
      fs.mkdirSync config.dirObj
    sourceFiles = glob.sync path.resolve(config.dirSource,config.project.sourceGlob)
    externalSourceFiles = glob.sync path.resolve(config.dirExternal,'src', config.project.sourceGlob)
    sourceFiles.push externalSourceFiles.join(' ')
    comp = [] #['-g','-x c++','-std=c++11']
    comp.push config.project.compilerDefines.join(' ')
    comp.push config.includeDirectories.join(' ')
    total = sourceFiles.length
    count = total
    for f in sourceFiles
      command = 'clang++ -g -c -o '+ path.resolve( config.dirObj, path.basename(f,'.cpp')+'.o')+' '+f+' '+comp.join(' ')
      exec command, (err, stdout, stderr) ->
        if count <= 0 then return
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
          # done()
        console.log parseInt( 100*(1-count/total) ).toString()+'%'

CompileIncremental = (done)->
  comp = [] #['-g','-x c++','-std=c++11']
  comp.push config.project.compilerDefines.join(' ')
  comp.push config.includeDirectories.join(' ')
  command = 'clang++ -x c++ -g -c - -o - '+comp.join(' ')
  console.log command
  sourceGlobs = [path.resolve(config.dirSource,config.project.sourceGlob), path.resolve(config.dirExternal,'src', config.project.sourceGlob) ]
  console.log sourceGlobs
  gulp.src sourceGlobs
  # .pipe newer config.dirObj
  # .pipe print (filepath)-> return 'NEWER: '+filepath
  # .pipe changed config.dirObj
  # .pipe print (filepath)-> return 'changed: '+filepath
  # .pipe cache 'source'
  .pipe run( command, {silent:true})
  .pipe print (filepath)-> return 'compiled: '+filepath
  .pipe rename { dirname: '', extname: '.o'}
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
      exec 'dsymutil -o '+path.resolve(config.dirOutput, config.project.outputExecutableName)+'.dSYM '+path.resolve(config.dirOutput, config.project.outputExecutableName), (err, stdout, stderr) ->
        if err then console.error err
    done()

Launch = (done)->
  app = spawn path.resolve(config.dirOutput, config.project.outputExecutableName), [], {stdio:'inherit'}
  app.on 'close', (code) ->
    console.log 'child process exited with code '+code
    done()

Prebuild = gulp.parallel Mustache, CSON, Assets
Build = gulp.series Prebuild, CompileAll, Link

gulp.task 'default', gulp.series Configure, Start
gulp.task 'config', Configure
gulp.task 'setup', Setup
gulp.task 'watch', watcher
gulp.task 'clean', Clean
gulp.task 'rebuild', gulp.series Clean, Build
gulp.task 'link', Link
gulp.task 'build', Build
gulp.task 'launch', gulp.series gulp.parallel(CSON, Assets), Launch
gulp.task 'test', lua
