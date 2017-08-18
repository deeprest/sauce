config = new (require './config.js')()
require 'shelljs/global'
os = require 'os'
fs = require 'fs'
path = require 'path'
child_process = require 'child_process'
glob = require 'glob'  # needed? gulp uses glob already
libclang = require 'libclang'
gulp = require 'gulp'
gutil = require 'gulp-util'
#cache = require 'gulp-cached'
#remember = require 'gulp-remember'
#shell = require('gulp-shell')
mustache = require "gulp-mustache"
rename = require "gulp-rename"
#changed = require 'gulp-changed'

# MUSTACHERY
module.exports = ->

  CreateTask_mustache = ( params ) ->
    gulp.task params.taskname, (cb) ->
      gulp.src( params.templatefilename, {cwd:config.dirSource} )
      .pipe( mustache( params.context ) )
      .pipe( rename( params.rename ))
      .pipe( gulp.dest( config.dirGeneratedSourceOutput ))
