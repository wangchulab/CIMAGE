define([
    'jquery',
], function($) {
    $(function() {
        var $el = $('<div />').insertBefore('table'),
            medianRatio = getMedianOfMedians();
        $el.append('<span />').text('Median of medians: ' + medianRatio);
    });

    function getMedianOfMedians() {
        // function taken from 
        // http://caseyjustus.com/finding-the-median-of-an-array-with-javascript
        function median(values) {

            values.sort( function(a,b) {return a - b;} );

            var half = Math.floor(values.length/2);

            if(values.length % 2)
                return values[half];
            else
                return (values[half-1] + values[half]) / 2.0;
        }
        var $rows = $('tbody tr').slice(2),
            ratios = [];
        $rows.each(function() {
            var $this = $(this);
            if (!$.trim($this.find('td:first').text())) {
                var ratio = parseFloat($this.find('td').eq(6).text());
                if (ratio) ratios.push(ratio);
            }
        });

        return median(ratios);
    }

    return function() {};
});