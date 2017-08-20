path = require 'path'
fs = require 'fs'
os = require 'os'
# child_process = require 'child_process'
exec = (require 'child_process').exec

yargs = require('yargs').argv
cson = require 'cson'
#require 'shelljs/global'
glob = require 'glob'  # nee
streamqueue = require 'streamqueue'

gulp = require 'gulp'
gutil = require 'gulp-util'
rename = require "gulp-rename"
mustache = require "gulp-mustache"
format = require 'gulp-clang-format'
watch = require 'gulp-watch'
replace = require 'gulp-replace'

libclang = require 'libclang'

config = new (require './js/config.js')()
#(require './js/binding.js')()

# merge two objects; latter overwrites conflicting properties of the former.
merge = (xs...) ->
  if xs?.length > 0
    tap {}, (m)-> m[k]=v for k,v of x for x in xs
tap = (o, fn) -> fn(o); o


gulp.task 'default', (cb) ->
    gulp.start 'build'
    #gulp.start 'watch-source'
    #gulp.start 'watch-mustache'
    # gulp.start 'watch-format'  # NOTE: there is an issue with reformatted source triggering a new build endlessly
    #gulp.start 'watch-assets'


gulp.task 'config', ->
  if yargs.config == undefined
    yargs.config = 'example.cson'
  console.log yargs.config
  rs = fs.createReadStream yargs.config, {flags:'r',encoding:'utf8'}
  buffer = ''
  rs.on 'error', (err)->  console.log 'error: '+err
  rs.on 'data', (chunk) ->  buffer += chunk
  rs.on 'end', ->
    obj = cson.parse buffer
    config = merge config, obj
    console.log config



gulp.task 'watch-format', ->
  watch config.watchGlob, {cwd:path.resolve(config.dirSource), ignoreInitial:false, awaitWriteFinish:true }
  .pipe format.format 'file'
  .pipe replace /^(\s+)(else)\s+(if)/m, '$1$2\n$1$3'
  .pipe gulp.dest path.resolve config.dirSource

# watch assets for changes, and copy to executable's working directory
gulp.task 'watch-assets', ->
  watch config.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
  .pipe gulp.dest( config.dirOutput )

# watch mustache templates for changes
gulp.task 'watch-mustache', ->
  watchBindings = gulp.watch '*.mustache', {cwd:path.resolve(config.dirSource)}, ['mustache-source']
  watchBindings.on 'change', (event) ->
    console.log 'Mustache file ' + event.path + ' was ' + event.type + ', processing...'

# watch source files and build on demand
gulp.task 'watch-source', ->
  watcher = gulp.watch config.watchGlob, {cwd:path.resolve(config.dirSource)}, [ 'build' ]
  watcher.on 'change', (event) ->
    console.log 'Source file ' + event.path + ' was ' + event.type + ', building...'



gulp.task 'mustache-source', ['config'], (cb) ->
  gulp.src( config.mustache.sourceGlob, {cwd:config.dirSource} )
  .pipe( mustache( config.mustache.context ) )
  .pipe( rename( config.mustache.rename ))
  .pipe( gulp.dest( config.dirGeneratedSourceOutput ))


gulp.task 'prebuild', ['mustache-source'], ->
  # Prepare directory hierarchy
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


gulp.task 'build', ['prebuild'], (cb) ->
  exec "date", (err, stdout, stderr) ->
    if err then console.error err

    # copy assets over
    gulp.src config.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
    .pipe gulp.dest( config.dirOutput )

    sourceFiles = glob.sync path.resolve(config.dirSource,config.sourceGlob)
    clangArgs = [
      '-g'
      '-x c++'
      '-std=c++11'
      #'-ferror-limit' '-fno-strict-aliasing' '-fno-rtti' '-fno-exceptions'
    ]
    # config.platform specific flags
    switch config.platform

      when 'linux'
        LinkerArgs = [
          '-lstdc++'
          '-lm'
          '-lpthread'
          '-lSDL2main'
          '-lSDL2'
          #'-lSDL2_image'
          '-langelscript'
          '-lGL'
          # '-lGLEW'
          '-lphysfs'
        ]
        #clangArgs.push sourceFiles.join(' ')
        #LinkerArgs.push config.linkerDirectories
        #clangArgs.push '-Wl,' + LinkerArgs.join(',')
        #clangArgs.push config.compilerDefines.join(' ')
        #clangArgs.push config.includeDirectories.join(' ')
        break

      when 'darwin'
        LinkerArgs = [
          '-lstdc++'
          '-lm'
          '-liconv'
          '-lpthread'
          '-lSDL2main'
          '-lSDL2'
          #'-lSDL2_image'
          '-langelscript'
          '-lphysfs'
        ]
        Frameworks = [
          '-framework CoreVideo'
          '-framework GLKit'
          '-framework OpenGL'
          '-framework IOKit'
          # '-framework ForceFeedback'
          # '-lobjc'
          # '-framework Cocoa'
          # '-framework Carbon'
          # '-framework CoreAudio'
          # '-framework AudioToolbox'
          # '-framework AudioUnit'
        ]
        #clangArgs.push sourceFiles.join(' ')
        #LinkerArgs.push config.linkerDirectories
        #clangArgs.push '-Wl,' + LinkerArgs.join(',')
        #clangArgs.push config.compilerDefines.join(' ')
        #clangArgs.push Frameworks.join(' ')
        #clangArgs.push config.includeDirectories.join(' ')
        break

      when 'windows'
        ###
        clangArgs.push '-std=c++11'
        LinkerArgs.push '-lstdc++'
        LinkerArgs.push '-lmingw32'
        LinkerArgs.push '-lSDL2main'
        LinkerArgs.push '-lSDL2'
        #LinkerArgs.push '-lSDL2.dll'
        LinkerArgs.push '-lopengl32'
        LinkerArgs.push '-lglew32'
        LinkerArgs.push '-langelscript'
        config.linkerDirectories.push '-LC:/MinGW/lib/gcc/mingw32/4.9.3/debug'
        #need to fix mingw default system include paths.. clang support for mingw/windows is lacking?
        clangArgs.push '-isystem '+ path.resolve('C:/','MinGW','lib','gcc','mingw32','4.9.3','include','c++')
        clangArgs.push '-isystem '+ path.resolve('C:/','MinGW','lib','gcc','mingw32','4.9.3','include','c++','mingw32')
        gulp.src( path.resolve(config.dirLibrary, 'SDL-2.0.4-10002','build','.libs','SDL2.dll'))
        .pipe( gulp.dest( path.resolve(config.dirOutput) ) )
        clangArgs.push config.compilerDefines.join(' ')
        clangArgs.push config.includeDirectories.join(' ')
        LinkerArgs.push config.linkerDirectories
        clangArgs.push '-Wl,' + LinkerArgs.join(',')
        clangArgs.push sourceFiles.join(' ')
        ###
        break

      else
        console.log "platform "+ config,platform +"not supported by build script!"

    console.log 'Compiling for platform: ' + config.platform
    # TODO: incremental rebuilding
    # clangCommand = ['clang++ -S -save-temps -g', clangArgs.join(' ')].join(' ')


    comp = [
      '-g'
      '-x c++'
      '-std=c++11'
    ]
    comp.push config.compilerDefines.join(' ')
    comp.push config.includeDirectories.join(' ')

    fs.mkdir config.dirObj, (err) ->
      #if err then console.error err
      total = sourceFiles.length
      count = total
      for f in sourceFiles
        command = 'clang++ -g -c -o '+ path.resolve( config.dirObj, path.basename(f,'.cpp')+'.o')+' '+f+' '+comp.join(' ')
        exec command, (err, stdout, stderr) ->
          if err
            console.error err
            return
          count--;
          console.log parseInt( 100*(1-count/total) ).toString()+'%'
          if count == 0
            link = []
            LinkerArgs.push config.linkerDirectories
            link.push '-Wl,' + LinkerArgs.join(',')
            if config.platform == 'darwin'
              link.push Frameworks.join(' ')
            linkCommand = ['clang++ -g', path.resolve( config.dirObj,'*.o'), link.join(' '),  '-o', path.resolve(config.dirOutput, config.outputExecutableName) ].join(' ')
            #console.log linkCommand
            exec linkCommand, (err, stdout, stderr) ->
              if err
                console.error err
                return
              else
                if config.platform == 'darwin'
                  exec 'dsymutil -o '+path.resolve(config.dirOutput, config.outputExecutableName)+'.dSYM '+path.resolve(config.dirOutput, config.outputExecutableName), (err, stdout, stderr) ->
                    if err then console.error err
                    cb()
                else
                  cb()

    ###
    # MONOLITHIC build

    clangArgs.push sourceFiles.join(' ')
    LinkerArgs.push config.linkerDirectories
    clangArgs.push '-Wl,' + LinkerArgs.join(',')
    clangArgs.push config.compilerDefines.join(' ')
    clangArgs.push Frameworks.join(' ')
    clangArgs.push config.includeDirectories.join(' ')
    clangCommand = ['clang++ --verbose -g -o', path.resolve(config.dirOutput, config.outputExecutableName), clangArgs.join(' ')].join(' ')
    console.log clangCommand
    exec clangCommand, (error, stdout, stderr) ->
      if error then return cb(error)
      console.log stdout
      console.log stderr
      cb()
    ###
