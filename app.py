from flask import Flask, Response, redirect, url_for, request
import re
from github import Github

app = Flask(__name__, subdomain_matching=True)


@app.route("/")
def print_content():
    result = re.match("^https?:\/\/get.", request.url)
    if result is not None:
        if request.method == "GET":
            with open("install_script.sh", "r") as f:
                file_content = f.read()  # Read whole file in the file_content string
                return Response(file_content, mimetype="text/plain")
        return Response("no get", mimetype="text/plain")
    else:
        with open("index.html", "r") as f:
            file_content = f.read()  # Read whole file in the file_content string
            return Response(file_content, mimetype="text/html")


@app.route("/", subdomain="foo")
def print_foo():
    return Response("foo worked", mimetype="text/plain")


@app.route("/version")
def get_version():
    g = Github()
    r = g.get_repo("SAME-Project/SAMPLE-CLI-TESTER")
    all_releases = r.get_releases()
    return Response(all_releases[0].title, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="localhost", port=80, debug=True, threaded=True)