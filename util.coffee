fs = require 'fs'


exports.rmDirSync = (dirPath)->
  try
    files = fs.readdirSync dirPath
  catch e
    return;
  if (files.length > 0)
    for i in files
      filePath = dirPath + '/' + i
      if fs.statSync(filePath).isFile()
        fs.unlinkSync filePath
      else
        rmDir filePath
  fs.rmdirSync dirPath
