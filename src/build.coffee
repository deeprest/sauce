config = new (require './config.js')()
require 'shelljs/global'
os = require 'os'
fs = require 'fs'
path = require 'path'
exec = (require 'child_process').exec
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
streamqueue = require 'streamqueue'


module.exports = ->
  gulp.task 'build', ['mustache-source','prebuild'], (cb) ->

    exec "date", (err, stdout, stderr) ->
      if err then console.error err
      fs.mkdir config.dirBuildRoot, 0o0775, (err)->
        console.log 'Creating build root directory..'
        # if err then console.error err
        fs.mkdir config.dirObj, 0o0775, (err)->
          console.log 'Creating temp object directory..'
          # if err then console.error err
        fs.stat config.dirOutput, (err,stats)->
          console.log 'Creating platform build directory..'
          # if err then console.error err
          fs.mkdir config.dirOutput, 0o0775, (err)->
            fs.stat path.resolve(config.dirOutput, config.outputExecutableName), (err,stats)->
              console.log 'Removing existing target executable...'
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

        # copy assets over
        gulp.src config.AssetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
        .pipe gulp.dest( config.dirOutput )

        sourceFiles = glob.sync path.resolve(config.dirSource,config.SourceGlob)
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
