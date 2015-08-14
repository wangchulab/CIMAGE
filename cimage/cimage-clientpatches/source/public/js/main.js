require.config({
    paths: {
        jquery: 'vendor/jquery',
        underscore: 'vendor/underscore',
        imagesLoaded: 'vendor/imagesloaded.pkgd',
    }
});

require([
    'cimage-preview/js/preview',
    'cimage-annotate/js/annotate',
    'cimage-utils/js/utils'
], function(preview, annotate, utils) {

});