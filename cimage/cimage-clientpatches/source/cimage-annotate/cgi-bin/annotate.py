#!/usr/bin/python

import sys, json, os, urlparse, re

print "Content-type:application/json\r\n\r\n"

data = json.loads(sys.stdin.read())
path = urlparse.urlparse(data["file"]).path
m = re.match('^/~(\w+/)(.+)', path)
real_path = os.path.realpath('/home/' + m.group(1) + 'public_html/' + m.group(2))
txt_path = os.path.splitext(real_path)[0] + '.txt'

with open(txt_path) as raw_file:
    raw_data = raw_file.read()

    for a in data["annotations"]:
        r = re.compile('(=HYPERLINK.+"%s"\))' % (
            re.escape(a['link'])
        ))

        raw_data = re.sub(r, r'\1\tannotated', raw_data)

    result = {}

    try:
        with open(txt_path + '.annotated', 'w') as annotated_file:
            annotated_file.write(raw_data)
    except IOError, e:
        result['error'] = str(e)
    else:
        result['success'] = 'Annotated file successfully generated.'

print json.dumps(result)