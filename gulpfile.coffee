# SPAWN PROCESS AND SELF-COMPILE
path = require 'path'
fs = require 'fs'
child_process = require 'child_process'
gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'
config = new (require './js/config.js')()

# Running the 'spawn' task will watch for changes in **this** file and respawn the child process with the changes
childProc = null
SpawnProcess = (cp, cb) ->
  if cp != null
    console.log 'Killing... '+cp.pid
    cp.kill('SIGTERM')
  else
    newProc = child_process.spawn 'x-terminal-emulator', ['--execute','gulp']
    newProc.on 'close', (code,signal) ->
      console.log 'Process '+this.pid+' closed '+code+' '+signal
      SpawnProcess null, (newproc) ->
        childProc = newproc
    console.log 'New process: '+newProc.pid
    if cb!=undefined
      cb(newProc)

gulp.task 'coffee', ->
  gulp.src path.resolve process.cwd(), 'src', '*.coffee'
    .pipe coffee {bare: true}
    .on 'error', gutil.log
    .pipe gulp.dest './'

gulp.task 'spawn-process', ['coffee'], ->
  SpawnProcess childProc, (newProc) ->
    childProc = newProc

gulp.task 'spawn', ['spawn-process'], ->
  gulp.watch path.resolve( process.cwd(), 'src', '*.coffee'), ['spawn-process']

mustache = new (require './js/mustache.js')()
#(require './js/binding.js')()
(require './js/build.js' )()
(require './js/watch.js' )()


# TODO: read this object from engine config
mustache {
  taskname: 'mustache-source'
  templatefilename: '*.mustache'
  rename: { extname: "" }
  context:{
    Components: [
      {type:'Transform'}
      {type:'Camera'}
      {type:'Mesh'}
      {type:'MeshView'}
      {type:'Collider'}
    ]
  }
}

gulp.task 'default', ->
  #gulp.start 'watch-mustache'
  # gulp.start 'watch-format'  # NOTE: there is an issue with reformatted source triggering a new build endlessly
  gulp.start 'watch-source'
  #gulp.start 'watch-assets'
  #gulp.start 'build'

# Prepare directory hierarchy
gulp.task 'prebuild', ->
  console.log 'Preparing to build'
  fs.mkdir config.dirBuildRoot, 0o0775, (err)->
    # if err then console.error err
    fs.mkdir config.dirObj, 0o0775, (err)->
      # console.log 'Creating temp object directory..'
      # if err then console.error err
    fs.stat config.dirOutput, (err,stats)->
      # console.log 'Creating platform build directory..'
      # if err then console.error err
      fs.mkdir config.dirOutput, 0o0775, (err)->
        fs.stat path.resolve(config.dirOutput, config.outputExecutableName), (err,stats)->
          # console.log 'Removing existing target executable...'
          # if err then console.error err
          fs.unlink path.resolve(config.dirOutput, config.outputExecutableName), ->
            return
    if config.platform=='darwin'
      fs.stat path.resolve(config.dirOutput, config.outputExecutableName+'.dSYM'), (err,stats)->
        return
        # if err then console.error err
      fs.unlink path.resolve(config.dirOutput, config.outputExecutableName+'.dSYM'), (err)->
        return
        # if err then console.error err
