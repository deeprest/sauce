
fs = require 'fs'
path = require 'path'
config = new (require './config.js')()
gulp = require 'gulp'
format = require 'gulp-clang-format'
watch = require 'gulp-watch'
mustache = require "gulp-mustache"
replace = require 'gulp-replace'

module.exports = ->
  # gulp.task 'watch', [], ->
  #   gulp.start 'watch-assets'
  #   gulp.start 'watch-mustache'
  #   gulp.start 'watch-format'
  #   gulp.start 'watch-source'

  gulp.task 'watch-format', ->
    watch config.WatchGlob, {cwd:path.resolve(config.dirSource), ignoreInitial:false, awaitWriteFinish:true }
    .pipe format.format 'file'
    .pipe replace /^(\s+)(else)\s+(if)/m, '$1$2\n$1$3'
    .pipe gulp.dest path.resolve config.dirSource

  # watch assets for changes, and copy to executable's working directory
  gulp.task 'watch-assets', ->
    watch config.AssetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
    .pipe gulp.dest( config.dirOutput )

  # watch mustache templates for changes
  gulp.task 'watch-mustache', ->
    watchBindings = gulp.watch '*.mustache', {cwd:path.resolve(config.dirSource)}, ['mustache-source']
    watchBindings.on 'change', (event) ->
      console.log 'Mustache file ' + event.path + ' was ' + event.type + ', processing...'

  # watch source files and build on demand
  gulp.task 'watch-source', ->
    watcher = gulp.watch config.WatchGlob, {cwd:path.resolve(config.dirSource)}, [ 'build' ]
    watcher.on 'change', (event) ->
      console.log 'Source file ' + event.path + ' was ' + event.type + ', building...'
