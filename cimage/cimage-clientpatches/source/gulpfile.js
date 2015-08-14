var gulp = require('gulp');
var uglify = require('gulp-uglify');
var mainBowerFiles = require('main-bower-files');
var del = require('del');

gulp.task('uglify', ['clean', 'bower-files'], function() {
    var files = gulp.src(['public/js/*.js', 'cimage-*/js/*.js'])
        .pipe(uglify())
        .pipe(gulp.dest('dist'));
});

gulp.task('bower-files', function() {

    var bowerFiles = mainBowerFiles({
        paths: {
            bowerDirectory: 'public/bower_components',
            bowerrc: '.bowerrc',
            bowerJson: 'bower.json'
        }
    });

    gulp.src(bowerFiles)
        .pipe(uglify())
        .pipe(gulp.dest('dist/vendor'));
});

gulp.task('clean', function() {
    del(['dist/*'], function(err) {
        console.log('Dist cleaned.')
    });
});

gulp.task('default', ['uglify']);