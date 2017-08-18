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
mustache = require "gulp-mustache"
rename = require "gulp-rename"


#  BINDINGS
module.exports = ->

  # http://clang.llvm.org/doxygen/group__CINDEX__TYPES.html#gaad39de597b13a18882c21860f92b095a
  convertClangType = (str) ->
    #console.log libclang.Constant.CXCursorKind[obj.kind], type.canonical.spelling, type.canonical.displayname
    str = str.replace(/Uint32|GLenum/g, "uint32_t")
    str = str.replace(/Uint64/g, "uint64_t")
    str = str.replace(/Bool/g, "bool")
    str = str.replace(/Void/g, "void")
    str = str.replace(/Int|Long/g, "int32_t")
    str = str.replace(/UInt|ULong/g, "uint32_t")
    return str

  convertClangTypedefType = (type ) ->
    switch type.canonical.spelling
      when 'Void' then return 'void'
      when 'Bool' then return 'bool'
      when 'Char_U','UChar' then return 'uint8'
      when 'Char_S','SChar' then return 'int8'
      when 'UShort' then return 'uint16'
      when 'Short' then return 'int16'
      when 'UInt','ULong' then return 'uint32'
      when 'Int','Long' then return 'int32'
      when 'ULongLong' then return 'uint64'
      when 'LongLong' then return 'int64'
      when 'Float' then return 'float'
      when 'Double' then return 'double'
      when 'Pointer'
        pointerType = type.pointeeType.declaration.spelling
        #console.log 'pointeeType: '+ pointerType
        if pointerType.length == 0
          pointerType = 'void'
        return pointerType
      else
        return null #type.canonical.spelling


  class AngelScriptBindingParams
    sourceFile: null
    outputFilename: null
    includes:[]
    footerLines:[]
    includeCursorRegex:""
    excludeCursorRegex:""
    clangParams:[]

  #MustacheContextBindings =
  #  Declarations: []



  params = new AngelScriptBindingParams
  params.sourceFile = path.resolve( config.dirLibrary,config.platform,'include','GL','glew.h')
  params.includeCursorRegex = /(\bGL|\bgl[A-Z])/
  params.excludeCursorRegex = /@|_ARB\b|_NV\b|_ATI\b|_SGIS\b|_EXT\b|GLU|glu|GLvoid|GLsync|GLenum/
  params.clangParams = ['-x','c++']
  params.includes = [ 'GL/glew.h' ]


  bindingHeader =
    taskname: 'binding-header'
    templatefilename: 'Binding.h.mustache'
    outfilename: 'Binding.h'
    context: {
      Declarations: []
    }

  bindingSource =
    taskname: 'binding-source'
    templatefilename: 'Binding.cpp.mustache'
    outfilename: 'Binding.cpp'
    context: {
      Declarations: []
    }





  # Write the constants to an angelscript file because I apparently cannot register global constants through the registration interface
  WriteAngelScriptConstants = (params, generatedName ) ->
    rs = fs.createReadStream params.sourceFile, {flags:'r',encoding:'utf8'}
    ws = fs.createWriteStream path.resolve( config.dirAsset, 'script', generatedName+'.as' )
    ws.on 'error', (err)->
      console.log 'error: '+err
    stringBuffer = ''
    rs.on 'error', (err)->
      console.log 'error: '+err
    rs.on 'data', (chunk) ->
      # console.log chunk
      stringBuffer += chunk
    rs.on 'end', ->
      re = new RegExp( /^#define\s+(\w+)\W+((0x)?\d+)$/gm )
      splits = stringBuffer.match( re )
      kvarray = []
      for m in splits
        identifier = m.replace( re, '$1')
        value = m.replace(re,'$2')
        kvarray.push { token:identifier ,value:value }
      uniqBy = (a, key) ->
        seen = {}
        return a.filter (item) ->
          k = key( item )
          if seen.hasOwnProperty k
            #console.log 'skipping duplicate: ', k
            return false
          else
            seen[k] = true
            return true
      uniqueArray = uniqBy kvarray, (item) ->
        return item['token']
      #console.log uniqueArray
      for obj in uniqueArray
        ws.write 'const uint32 '+obj.token+' = '+obj.value+';\n'
      ws.end()

  CreateTask_bindings = ( taskname, params ) ->
    generatedName = path.basename(params.sourceFile).replace(/\./,'_')
    outputFilename = path.resolve(config.dirSource,'Binding-'+generatedName+'.cpp')
    # NOTE: params.context may need to exist as an object in higher scope for this to work correctly.
    # TODO: verify
    params.context.Declarations.push { name: generatedName }
    gulp.task taskname, (cb) ->
      WriteAngelScriptConstants params, generatedName
      ws = fs.createWriteStream outputFilename
      ws.write '// THIS FILE IS GENERATED\n'
      ws.write '#include "Binding.h"\n'
      for line in params.includes
        ws.write ['#include "',line,'"\n'].join('')
      ws.write ['void RegisterBindings_', generatedName,'( asIScriptEngine* engine )', '\n','{','\n','int r = 0;','\n'].join('')
      Cursor = libclang.Cursor
      Index = libclang.Index
      #Token = libclang.Token
      TranslationUnit = libclang.TranslationUnit
      index = new Index(true,true)
      tu = new TranslationUnit.fromSource( index, params.sourceFile, params.clangParams )
      functionDef = null
      tu.cursor.visitChildren (parent) ->
        if params.includeCursorRegex.test(this.spelling) == true && params.excludeCursorRegex.test(this.spelling) == false
          switch this.kind

            when Cursor.LastProcessing
              return Cursor.Break
              break

            when Cursor.FunctionDecl
              if functionDef != null
                ws.write functionDef.join(' ')
                functionDef = null
              # mark the functions that have pointers in the declaration
              modifiedFunc = this.displayname.replace(/\*/g, "@")
              modifiedFunc = convertClangType( modifiedFunc )
              if params.includeCursorRegex.test(modifiedFunc) == true && params.excludeCursorRegex.test(modifiedFunc) == false
                commentStr = ''
              else
                commentStr = '//'
              functionDef = [commentStr, 'r = engine->RegisterGlobalFunction( "', convertClangTypedefType( this.type.canonical.result ), modifiedFunc, '", asFUNCTION(', this.canonical.spelling, '), asCALL_CDECL ); SDL_assert( r>=0 );\n']
              return Cursor.Recurse
              break

            when Cursor.TypedefDecl
              actualType = convertClangTypedefType( this.typedefType )
              if actualType != null && actualType != 'void'
                ws.write 'r = engine->RegisterTypedef( "'+ this.spelling + '", "'+ actualType + '" ); SDL_assert( r>=0 );\n'
              return Cursor.Continue
              break

            when Cursor.ClassDecl
              console.log 'CLASS', this.spelling, this.kind.spelling, this.type.spelling
              ws.write 'r = engine->RegisterObjectType("'+this.spelling+'", sizeof('+this.spelling+'), asOBJ_VALUE | asOBJ_POD); SDL_assert( r >= 0 );\n'
              return Cursor.Recurse
              break

            when Cursor.FieldDecl
              console.log 'FIELD', this.spelling, this.kind.spelling, this.type.spelling
              #ws.write 'r = engine->RegisterObjectProperty("SDL_MouseButtonEvent", "int x", asOFFSET(SDL_MouseButtonEvent,x));\n'
              return Cursor.Continue
              break

            when Cursor.StructDecl
              console.log 'STRUCT', this.spelling, this.kind.spelling, this.type.spelling
              ws.write 'r = engine->RegisterObjectType("'+this.spelling+'", sizeof('+this.spelling+'), asOBJ_VALUE | asOBJ_POD); SDL_assert( r >= 0 );\n'
              return Cursor.Recurse
              break

            when Cursor.Record
              console.log 'RECORD', this.spelling, this.kind.spelling, this.type.spelling
              return Cursor.Recurse
              break

            when Cursor.MacroDefinition
              #console.log 'MacroDefinition!!!', this.displayname, this.type.declaration.spelling
              #console.log this.location.presumedLocation.line
              return Cursor.Recurse
              break

            when Cursor.MacroInstantiation
              #console.log 'MacroInstantiation!!!'
              return Cursor.Continue
              break

            when Cursor.IntegerLiteral
              console.log 'IntegerLiteral!!!'
              return Cursor.Continue
              break

        return Cursor.Recurse
      ws.write '}\n'
      ws.end()
      cb()


  # ANGELSCRIPT BINDINGS

  CreateTask_mustache bindingHeader
  CreateTask_mustache bindingSource
  CreateTask_bindings 'binding-glew', params

  gulp.task 'bindings', ->
    gulp.start 'binding-source'
    gulp.start 'binding-header'



  ###
  #gulp.start 'copyAssets'
  #gulp.start 'bindings-glew', (err) ->
    #if err!=undefined
    #  console.log 'ERROR:', err
    #gulp.start 'constants-glew', () ->
    #  console.log 'constants-glew is done!'
      #if err!=undefined
      #  console.log 'ERROR:', err
      #RenderMustacheTemplate 'Binding.h.mustache', 'Binding.h', MustacheContext, ->
      #  RenderMustacheTemplate 'Binding.cpp.mustache', 'Binding.cpp', MustacheContext, ->
  #cb()

  params.includeCursorRegex = /SDL_/
  params.excludeCursorRegex = /@|_SDL|dummy|alloc|SDL_[a-z]|SDL_SysWMmsg|SDL_Cursor|SDL_Window|SDL_BlitMap/
  params.sourceFile = path.resolve(config.dirLibrary, platform, 'include','SDL2','SDL_events.h')
  params.includes = [
    'SDL_stdinc.h'
    'SDL_events.h'
    'SDL_joystick.h'
    'SDL_gamecontroller.h'
    'SDL_mouse.h'
  ]
  #GenerateAngelScriptBindings( params )
  ###
  #gulp.src event.path
  #.pipe format.format()
  #  .pipe gulp.dest('test-format')


  ###
  gulp.task 'getlibs', ->
    #GetLib lib for lib in ExternalLibraries
    ExternalLibraries = [
      sdl =
        url:'https://www.libsdl.org/tmp/SDL-2.0.4-10002.tar.gz',
        downloadTo:'sdl.tar.gz',
        buildCommand:'cd '+path.resolve(config.dirLibrary,'SDL-2.0.4-10002')+'; sudo ./configure; sudo make;'
        #includeDir:'-I' + path.resolve(config.dirLibrary, 'SDL-2.0.4-10002','include')
      ,
      angelscript =
        url:'http://www.angelcode.com/angelscript/sdk/files/angelscript_2.30.2.zip',
        downloadTo:'angelscript.zip',
        buildCommand:'cd '+path.resolve(config.dirLibrary,'sdk','angelscript','projects','gnuc macosx')+'; make;',
        includeDir: [
          '-I' + path.resolve(config.dirLibrary, 'sdk', 'angelscript','include')
          '-I' + path.resolve(config.dirLibrary, 'sdk', 'add_on', 'scriptbuilder','include')
          '-I' + path.resolve(config.dirLibrary, 'sdk', 'add_on', 'scriptstdstring','include')
        ]
      ,
      ,
      box2d =
        url: 'https://codeload.github.com/erincatto/Box2D/tar.gz/v2.3.1',
        downloadTo:'box2d.tar.gz',
        buildCommand:'cd '+path.resolve(config.dirLibrary, 'Box2D-2.3.1','Box2D','Build')+'; cmake -DBOX2D_INSTALL=ON -DBOX2D_BUILD_SHARED=ON ..; make'
    ]
    #RunCommand config.dirLibrary, 'curl http://www.angelcode.com/angelscript/sdk/files/angelscript_2.30.2.zip > angelscript.zip; unzip angelscript.zip -d angelscript'
    for lib in ExternalLibraries
      child_process.exec 'curl '+obj.url+' > '+obj.downloadTo+'; tar -xf '+obj.downloadTo+'; '+obj.buildCommand+';', { cwd: config.dirLibrary }, (err, stdout, stderr) ->
      #sudo ./configure; make;', { cwd: config.dirLibrary }, (err, stdout, stderr) ->
        console.log stdout.toString()
        console.log stderr.toString()
  ###
