#!/bin/zsh

cd <path/to/your/project/folder>

# runs the main app and pings the local host to generate the static html file locally
python3 -m flask run & sleep 3 && curl http://127.0.0.1:5000

# kills all the processes running on port 5000, so that you can run the html generation again later
kill -9 $(lsof -t -i:"5000")

# runs surge to publish your html page into production at the domain name of your choice
cd <path/to/your/static/folder>
surge <path/to/your/static/folder> --domain https://your.domain.name.surge.sh 






