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

@app.route('/api/resetCloudNsxOverlay', methods=['POST'])
def resetCloudNsxOverlay():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootCloudFix.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    process = subprocess.Popen(['/bin/bash', 'resetCloudNsxOverlay.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
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

@app.route('/api/tshootPool', methods=['POST'])
def tShootPool():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootPool.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/initializeYourVs', methods=['POST'])
def initializeYourVs():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'initializeYourVs.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootTlsVsPool', methods=['POST'])
def tshootTlsVsPool():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootTlsVsPool.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootIntermittentVs01', methods=['POST'])
def tshootIntermittentVs01():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootIntermittentVs01.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootIntermittentVs02', methods=['POST'])
def tshootIntermittentVs02():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootIntermittentVs02.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/gslbInfrastructureSiteB', methods=['POST'])
def gslbInfrastructureSiteB():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'gslbInfrastructureSiteB.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootGslbService', methods=['POST'])
def tshootGslbService():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootGslbService.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/authLdapVs', methods=['POST'])
def authLdapVs():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'authLdapVs.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootPoolAuth', methods=['POST'])
def tshootPoolAuth():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootPoolAuth.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/createMultipleVs', methods=['POST'])
def createMultipleVs():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'createMultipleVs.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

# Start the server
if __name__ == '__main__':
    app.run()