define([
    'imagesLoaded',
    'jquery'
], function(imagesLoaded, $) {
    var previewWrap = document.createElement('div'),
        preview = document.createElement('img');
    previewWrap.style.position = 'absolute';
    previewWrap.style.background = 'white';
    previewWrap.style.border = '1px solid black';
    previewWrap.style.transition = 'opacity 0.4s';
    previewWrap.appendChild(preview);
    document.body.appendChild(previewWrap);

    function showPreview(e) {
        e.preventDefault();

        if (hidePreviewHandle) {
            clearTimeout(hidePreviewHandle);
        }
        
        var el = e.currentTarget,
            parent = el.parentNode,
            x = parent.offsetLeft - parent.clientWidth,
            y = parent.offsetTop;

        previewWrap.style.display = 'block';
        preview.src = el.href;

        imagesLoaded(preview, function() {
            previewWrap.style.opacity = 1;
            previewWrap.style.left = x - (previewWrap.clientWidth || preview.width);
            previewWrap.style.top = y + ((previewWrap.clientHeight || preview.height) / 2);
            console.log(y + ((previewWrap.clientHeight || preview.height) / 2));
        });
    }

    var hidePreviewHandle;

    function hidePreview() {
        previewWrap.style.opacity = 0;
        hidePreviewHandle = setTimeout(function() {
            previewWrap.style.display = 'none';
        }, 500);
    }

    function bindEvents() {
        var imageLinks = document.querySelectorAll('tr td:last-of-type a');
        for (var i = 0, n = imageLinks.length; i < n; i++) {
            imageLinks[i].addEventListener('mouseenter', showPreview, false);
            imageLinks[i].addEventListener('mouseleave', hidePreview, false);
        }
    }; 

    // execute immediately for convenience
    bindEvents();

    // then we bind again
    // according to spec, addEventListener automagically removes duplicate events
    // probably should just delegate events instead
    $(function() {
        bindEvents(); 
    });

    return function() {};
});