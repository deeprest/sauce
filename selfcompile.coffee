# SPAWN PROCESS AND SELF-COMPILE
path = require 'path'
fs = require 'fs'
child_process = require 'child_process'
gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'
config = new (require './config.js')()

# Running the 'spawn' task will watch for changes in **this** file and respawn the child process with the changes
childProc = null
SpawnProcess = (cp, cb) ->
  if cp != null
    console.log 'Killing... '+cp.pid
    cp.kill('SIGTERM')
  else
    emulator = 'x-terminal-emulator'
    newProc = child_process.spawn emulator, ['--execute','gulp']
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
