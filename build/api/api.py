from flask import Flask
import subprocess
import json
from flask_restful import Api, Resource, reqparse, abort
from flask_cors import CORS

# Creating a Flask app
app = Flask(__name__)
cors = CORS(app)

@app.route('/api/module04b', methods=['POST'])
def module04b():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'module04b.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    if process.returncode != 0:
      return "Config. not applied", 500
    if process.returncode == 0:
      return "Config. applied", 201

@app.route('/api/module04bfix', methods=['POST'])
def module04bfix():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'module04b_fix.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    if process.returncode != 0:
      return "Config. not applied", 500
    if process.returncode == 0:
      return "Config. applied", 201

# Start the server
if __name__ == '__main__':
    app.run()