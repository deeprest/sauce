// Generated by CoffeeScript 1.12.7
(function() {
  var SpawnProcess, childProc, child_process, coffee, config, fs, gulp, gutil, path;

  path = require('path');

  fs = require('fs');

  child_process = require('child_process');

  gulp = require('gulp');

  gutil = require('gulp-util');

  coffee = require('gulp-coffee');

  config = new (require('./config.js'))();

  childProc = null;

  SpawnProcess = function(cp, cb) {
    var emulator, newProc;
    if (cp !== null) {
      console.log('Killing... ' + cp.pid);
      return cp.kill('SIGTERM');
    } else {
      emulator = 'x-terminal-emulator';
      newProc = child_process.spawn(emulator, ['--execute', 'gulp']);
      newProc.on('close', function(code, signal) {
        console.log('Process ' + this.pid + ' closed ' + code + ' ' + signal);
        return SpawnProcess(null, function(newproc) {
          return childProc = newproc;
        });
      });
      console.log('New process: ' + newProc.pid);
      if (cb !== void 0) {
        return cb(newProc);
      }
    }
  };

  gulp.task('coffee', function() {
    return gulp.src(path.resolve(process.cwd(), 'src', '*.coffee')).pipe(coffee({
      bare: true
    })).on('error', gutil.log).pipe(gulp.dest('./'));
  });

  gulp.task('spawn-process', ['coffee'], function() {
    return SpawnProcess(childProc, function(newProc) {
      return childProc = newProc;
    });
  });

  gulp.task('spawn', ['spawn-process'], function() {
    return gulp.watch(path.resolve(process.cwd(), 'src', '*.coffee'), ['spawn-process']);
  });

}).call(this);