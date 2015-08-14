from flask import Flask, request, jsonify, json
from pymongo import MongoClient
from bson import json_util

app = Flask(__name__)
app.debug = True

@app.route('/', methods=['GET', 'POST', 'OPTIONS'])
def index():
    data = json.loads(request.args.get('data'))

    client = MongoClient()
    db = client.annotations
    coll = db.annotations

    result = ''

    # if we're passed annotations then save them
    if 'annotations' in data:
        if data.get('annotations'):
            coll.save(data)
        # if annotations array is empty then we can ditch that document
        else: 
            coll.remove({ 'file': data.get('file') })
    else:
        result = coll.find_one({ "file": data.get('file') })

    return json_util.dumps(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0')