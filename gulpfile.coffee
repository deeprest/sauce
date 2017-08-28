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

# apt = require 'apt'
yargs = require('yargs').argv
cson = require 'cson'
glob = require 'glob'  # TODO: remove
merge = require 'deepmerge'

stream = require 'stream' # TEMP

config = new (require './config.js')()
#(require './binding.js')()

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
    switch config.platform
      when 'linux'
        target = config.target.linux
        break
      when 'darwin'
        target = config.target.darwin
        break
      else
        console.log "platform "+ config,platform +"not supported by build script!"
    config.project = merge config.project, target
    # console.log config
    console.log 'Configured for platform: ' + config.platform
    done()


Clean = (done)->
  # fs.rmdir config.dirObj
  fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName), ->{}
  if config.platform=='darwin'
    fs.stat path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err,stats)->
      fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err)->
        done()
  else done()

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
  gulp.watch '**/*.cson', CSON
  gulp.watch config.project.assetGlob, Mustache

CompileAll = (done)->
  if fs.existsSync config.dirObj == false
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
      if err then console.error err; return
      console.log stdout
      count--;
      console.log parseInt( 100*(1-count/total) ).toString()+'%'
      if count == 0
        done()

# TODO
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
  if config.platform == 'darwin'
    link.push frameworks.join(' ')
  objectFiles = glob.sync config.dirObj+'/**/*.o'
  linkCommand = ['clang++ -g', objectFiles.join(' '), link.join(' '),  '-o', path.resolve( config.dirOutput, config.project.outputExecutableName) ].join(' ')
  # console.log linkCommand
  exec linkCommand, (err, stdout, stderr) ->
    console.log stdout
    console.log stderr
    if err then console.error 'LINK ERROR: '+err
    else if config.platform == 'darwin'
      exec 'dsymutil -o '+path.resolve(config.dirOutput, config.project.outputExecutableName)+'.dSYM '+path.resolve(config.dirOutput, config.project.outputExecutableName), (err, stdout, stderr) ->
        if err then console.error err
    done()


Launch = (done)->
  app = spawn path.resolve(config.dirOutput, config.project.outputExecutableName), [], {stdio:'inherit'}
  app.on 'close', (code) ->
    console.log 'child process exited with code '+code
    done()

Prebuild = gulp.parallel Mustache, CSON, Assets
Rebuild = gulp.series Clean, Prebuild, CompileAll #, Link

gulp.task 'config', Configure
gulp.task 'watch', watcher
gulp.task 'rebuild', Rebuild
gulp.task 'link', Link
gulp.task 'build', gulp.series CompileAll, Link
gulp.task 'launch', Launch
gulp.task 'default', gulp.series Configure, Start
