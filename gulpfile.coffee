coffee = require 'gulp-coffee'
coffeelint = require 'gulp-coffeelint'
del = require 'del'
gulp = require 'gulp'
watch = require 'gulp-watch'

gulp.task 'lint:coffee', ->
  gulp.src('src/**/*.coffee')
    .pipe(do coffeelint)
    .pipe(do coffeelint.reporter)

gulp.task 'clean', (done) ->
  del ['dist'], done

gulp.task 'build:coffee', ['clean', 'lint:coffee'], ->
  gulp.src('src/**/*.coffee')
    .pipe(do coffee)
    .pipe(gulp.dest 'dist')

# The default task
gulp.task 'default', ['build:coffee']

gulp.task 'watch', ->
  watch 'src/**/*.coffee', ->
    gulp.start 'default'

gulp.task 'develop', ['default', 'watch']
