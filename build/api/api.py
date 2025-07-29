from flask import Flask
import subprocess
import json
from flask_restful import Api, Resource, reqparse, abort
from flask_cors import CORS

# Creating a Flask app
app = Flask(__name__)
cors = CORS(app)

@app.route('/api/tshootCloud', methods=['POST'])
def tshootCloud():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootCloud.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootCloudFix', methods=['POST'])
def tshootCloudFix():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootCloudFix.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/rollBackSegSizing', methods=['POST'])
def rollBackSegSizing():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'rollBackSegSizing.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootScaleOut', methods=['POST'])
def tshootScaleOut():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootScaleOut.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootHttpHeader', methods=['POST'])
def tshootHttpHeader():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootHttpHeader.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

# Start the server
if __name__ == '__main__':
    app.run()