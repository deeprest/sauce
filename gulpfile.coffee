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
libclang = require 'libclang'
merge = require 'deepmerge'

gulp = require 'gulp'
rename = require "gulp-rename"
mustache = require "gulp-mustache"
# format = require 'gulp-clang-format'
watch = require 'gulp-watch'
replace = require 'gulp-replace'
gulpcson = require 'gulp-cson'
print = require 'gulp-print'

config = new (require './js/config.js')()
#(require './js/binding.js')()


gulp.task 'default', (cb) ->
  gulp.start 'build'


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
    # console.log config


gulp.task 'autobuild', ['config'], ->
  watch config.project.watchGlob, {cwd:path.resolve(config.dirSource)}, [ 'build' ]
  .pipe print( (filepath)=> return 'Build triggered from change: '+filepath; )


gulp.task 'watch', ['config'], ->
  # watch config.project.watchGlob, {cwd:path.resolve(config.dirSource), ignoreInitial:false, awaitWriteFinish:true }
  # .pipe print( (filepath)=> return 'Formatting source file: '+filepath; )
  # .pipe format.format 'file'
  # .pipe replace /^(\s+)(else)\s+(if)/m, '$1$2\n$1$3'
  # .pipe gulp.dest path.resolve config.dirSource
  watch config.project.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
  .pipe print( (filepath)=> return 'Asset copied: '+filepath; )
  .pipe gulp.dest( config.dirOutput )
  watch '**/*.cson', {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
  .pipe gulpcson()
  .pipe print( (filepath)=> return 'CSON=>JSON: '+filepath; )
  .pipe gulp.dest( config.dirOutput )
  watch config.mustache.sourceGlob, {cwd:path.resolve(config.dirSource)}
  .pipe mustache( config.mustache.context )
  .pipe rename( config.mustache.rename )
  .pipe print (filepath)=> return 'Mustaching: '+filepath;
  .pipe gulp.dest( config.dirGeneratedSourceOutput )


gulp.task 'mustache-source', ['config'], ->
  # gulp.src config.mustache.sourceGlob, {cwd:path.resolve(config.dirSource)}
  # .pipe mustache( config.mustache.context )
  # .pipe rename( config.mustache.rename )
  # .pipe print (filepath)=> return 'Mustaching: '+filepath;
  # .pipe gulp.dest( config.dirGeneratedSourceOutput )


gulp.task 'prebuild', ['config','mustache-source'], ->
  # copy assets over
  gulp.src config.project.assetGlob, {cwd:path.resolve(config.dirAsset), ignoreInitial:false, awaitWriteFinish:true }
  .pipe gulp.dest( config.dirOutput )
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
        fs.stat path.resolve(config.dirOutput, config.project.outputExecutableName), (err,stats)->
          # console.log 'Removing existing target executable...'
          # if err then console.error err
          fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName), ->
            return
    if config.platform=='darwin'
      fs.stat path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err,stats)->
        return
        # if err then console.error err
      fs.unlink path.resolve(config.dirOutput, config.project.outputExecutableName+'.dSYM'), (err)->
        return
        # if err then console.error err


gulp.task 'build', ['prebuild'], (cb) ->
  exec "date", (err, stdout, stderr) ->
    if err then console.error err

    target = undefined
    sourceFiles = glob.sync path.resolve(config.dirSource,config.project.sourceGlob)
    externalSourceFiles = glob.sync path.resolve(config.dirExternal,'src', config.project.externalSourceGlob)
    # console.log 'EXTERNAL'
    # console.log externalSourceFiles.join(' ')
    sourceFiles.push externalSourceFiles.join(' ')
    # console.log 'SOURCE'
    # console.log sourceFiles.join(' ')

    switch config.platform
      when 'linux'
        target = config.target.linux
        break
      when 'darwin'
        target = config.target.darwin
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
        ###
        break
      else
        console.log "platform "+ config,platform +"not supported by build script!"

    # console.log target
    target = merge config.project, target
    # console.log target

    console.log 'Compiling for platform: ' + config.platform
    # TODO: incremental rebuilding
    # clangCommand = ['clang++ -S -save-temps -g', clangArgs.join(' ')].join(' ')

    comp = []
    #   '-g'
    #   '-x c++'
    #   '-std=c++11'
    # ]

    comp.push target.compilerDefines.join(' ')
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
            LinkerArgs = target.LinkerArgs
            LinkerArgs.push config.linkerDirectories
            link.push '-Wl,' + LinkerArgs.join(',')
            if config.platform == 'darwin'
              link.push Frameworks.join(' ')
            linkCommand = ['clang++ -g', path.resolve( config.dirObj,'*.o'), link.join(' '),  '-o', path.resolve(config.dirOutput, config.project.outputExecutableName) ].join(' ')
            #console.log linkCommand
            exec linkCommand, (err, stdout, stderr) ->
              if err
                console.error err
                return
              else
                if config.platform == 'darwin'
                  exec 'dsymutil -o '+path.resolve(config.dirOutput, config.project.outputExecutableName)+'.dSYM '+path.resolve(config.dirOutput, config.project.outputExecutableName), (err, stdout, stderr) ->
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
