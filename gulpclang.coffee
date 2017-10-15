
Stream = require 'stream'
Path = require 'path'

map = require 'map-stream'
rext = require 'replace-ext'

os = require 'os'
path = require 'path'
fs = require 'fs'
child_process = (require 'child_process')

module.exports = (obj) ->
  # console.log 'clang: '+obj.command
  obj = {} unless obj
  indent = if typeof obj.indent == 'string' or obj.indent == null then obj.indent else '  '


  # compileMapped = (file, cb) ->
  #   console.log file
  #   console.log obj.command
  #   # file.contents = new Buffer() # JSON.stringify json, null, indent
  #   file.contents = child_process.execSync obj.command, {maxBuffer: 1024 * 1024 * 10}
  #   # child_process.exec obj.command, {maxBuffer: 1024 * 1024 * 10}, (err,stdout,stderr)->
  #
  #     # file.contents = new Buffer(stdout)
  #   file.path = rext file.path, '.o'
  #   console.log file.contents
  #   # console.log 'CLANG++'
  #   # console.log stdout
  #   # console.log stderr
  #   # if err then console.error 'CLANG ERROR: '+err
  #   cb null, file
  #
  # return map compileMapped

  stream = new Stream.Transform {objectMode: true}

  parsePath = (path)->
    extname = Path.extname(path)
    return {
      dirname: Path.dirname(path)
      basename: Path.basename(path, extname)
      extname: extname
    }

  stream._transform = (file, unused, callback) ->

    console.log file
    console.log obj.command
    # file.contents = new Buffer() # JSON.stringify json, null, indent
    # file.contents = child_process.execSync obj.command, {maxBuffer: 1024 * 1024 * 10}
    child_process.exec 'echo hello', {maxBuffer: 1024 * 1024 * 10}, (err,stdout,stderr)->

      # file.contents = new Buffer(stdout)
      file.path = rext file.path, '.o'
      console.log file.contents
      # console.log 'CLANG++'
      # console.log stdout
      # console.log stderr
      # if err then console.error 'CLANG ERROR: '+err
      callback null, file

    # parsedPath = parsePath(file.relative)
    # path={}
    # type = typeof obj;
    # if type == 'string' && obj != ''
    #   path = obj;
    # else if type == 'function'
    #   obj(parsedPath);
    #   path = Path.join(parsedPath.dirname, parsedPath.basename + parsedPath.extname)
    # else if obj? && type == 'object'
    #   dirname = 'dirname' in obj ? obj.dirname : parsedPath.dirname,
    #     prefix = obj.prefix || '',
    #     suffix = obj.suffix || '',
    #     basename = 'basename' in obj ? obj.basename : parsedPath.basename,
    #     extname = 'extname' in obj ? obj.extname : parsedPath.extname
    #   path = Path.join(dirname, prefix + basename + suffix + extname)
    # else
    #   callback(new Error('Unsupported renaming parameter type supplied'), undefined)
    #   return

    # file.path = Path.join(file.base, path)
    # #  Rename sourcemap if present
    # if file.sourceMap
    #   file.sourceMap.file = file.relative

    # callback null, file

  return stream
