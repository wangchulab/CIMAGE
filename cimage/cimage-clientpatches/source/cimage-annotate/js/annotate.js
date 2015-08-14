define([
    'jquery',
    'underscore'
], function($, _) {

    var initAnnotations = {},
        byPeptide = false;

    $(function() {
        var $rows = $('tbody tr'),
            $lastHeader = $rows.eq(0).find('th:last');

        // adding column for annotation checkbox
        $lastHeader.after($lastHeader.clone().text('annotate'));
        // adding empty column since there are two sets of headers
        $rows.eq(1).find('th:last').after($lastHeader.clone().empty());

        $('colgroup:last').after('<colgroup span=1 />');

        // working with non header rows now
        $rows = $rows.slice(2);

        // determine whether or not we've organized things by protein or by
        // peptide. When organized by protein there is an IPI next to each
        // index.
        byPeptide = !$.trim($rows.eq(0).children('td').eq(1).text());

        $rows.append('<td />');

        var $checkbox = $('<input type="checkbox" />');

        // add checkbox to each row
        $rows.each(function() {
            var $this = $(this);
            if (!$.trim($this.find('td:first').text())) {
                $this.find('td:last').html($checkbox.clone());
            } 
        });

        // fetch annotations from server
        fetchAnnotations();

        // update annotations whenever a checkbox is clicked
        $('input[type="checkbox"]').on('change', updateAnnotations);
    });

    function fetchAnnotations() {
        $.ajax({
            url:'/annotate',
            data: {
                data: JSON.stringify({
                    file: window.location.href
                })                
            }
        }).success(function(data) {
            initAnnotations = JSON.parse(data);

            if (!initAnnotations) return;

            initAnnotations._id = initAnnotations._id.$oid;
            var annotatedLinks = _.pluck(initAnnotations.annotations, 'link');

            $('input[type="checkbox"]').each(function() {

                // if we've already checked all the boxes that we needed to
                // we can return early
                if (!annotatedLinks.length) return;

                var $this = $(this),
                    link = $this.parent().prev().text().trim(),
                    index = annotatedLinks.indexOf(link);

                if (index != -1) {
                    $this.prop('checked', true);
                    annotatedLinks.splice(index, 1);
                }
            });
        }); 
    }

    function mapElementsToData($checkbox) {
        // index of column where to find corresponding information 
        var map = {
            ipi: 1, 
            symbol: 3,
            sequence: 4,
            charge: (byPeptide) ? 9 : 11,
            segment: (byPeptide) ? 10 : 12,
            link: (byPeptide) ? 11 : 13
        };

        var $els = $checkbox.parent().siblings(),
            data = {
                sequence: $.trim($els.eq(map.sequence).text()),
                charge: Math.round($els.eq(map.charge).text()),
                segment: Math.round($els.eq(map.segment).text()),
                link: $.trim($els.eq(map.link).text())
            };

        // if things are sorted by protein, then the ipi, symbol and sequence
        // are found in the heading, so we have to traverse DOM up until that
        // row to get it
        if (!byPeptide) {
            var $el = $checkbox.parents('tr');

            do {
                $el = $el.prev();
            } while (!$.trim($el.text()));

            $els = $el.children();
        }

        return _.extend(data, {
            ipi: $.trim($els.eq(map.ipi).text()),
            symbol: $.trim($els.eq(map.symbol).text()),
            index: Math.round(data.link.split('.')[0])
        });
    }

    function updateAnnotations() {
        console.log(initAnnotations);
        var annotationSet = initAnnotations || {
            file: window.location.href,
            annotations: []
        };

        // use the filename as the unique identifier.
        // reasonable assumption since URLs are unique
        // can run into problems if someone reprocesses their data and things
        // no long line up
        annotationSet._id = annotationSet.file;
        initAnnotations = annotationSet;

        var $this = $(this),
            data = mapElementsToData($this);

        // if checkbox is checked then just add to array of annotations
        if ($this.prop('checked')) {
            annotationSet.annotations.push(data);
        } else {
            annotationSet.annotations = _.reject(annotationSet.annotations, function(a) {
                return _.isEqual(a, data);
            });
        }

        // generate combined_dta.txt.annotated
        $.ajax({
            type: 'POST',
            url: '/cgi-bin/radu/annotate.py',
            data: JSON.stringify(annotationSet)
        });

        // save stuff to mongodb for persistance
        $.ajax({
            url: '/annotate',    
            data: {
                'data': JSON.stringify(annotationSet)
            }
        });
    }
});