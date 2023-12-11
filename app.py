from datetime import datetime
from dotenv import load_dotenv
from flask import Flask, render_template
import os
import requests
import sqlite3
import string


# Configure application
app = Flask(__name__)

# Ensure responses aren't cached
@app.after_request
def after_request(response):
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Expires"] = 0
    response.headers["Pragma"] = "no-cache"
    return response

# Load environment variables
load_dotenv()

# Connect to KnowledgeC.db
KNOWLEDGE_DB_PATH = os.environ['KNOWLEDGE_DB_PATH']
con = sqlite3.connect(KNOWLEDGE_DB_PATH, check_same_thread=False)

@app.route("/")
def screentime_dashboard():
    # Query KnowledgeC.db to get Screentime data for the day by bundle_id and in descending order
    # This SQL query was adapted from APOLLO's knowledge_app_usage module - https://github.com/mac4n6/APOLLO/blob/master/modules/knowledge_app_usage.txt - see License for full copyright statement
    with con:
        cur = con.cursor()
        cur.execute("""
                    SELECT 
                        ZOBJECT.ZVALUESTRING AS "BUNDLE ID", 
                        SUM(ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE) AS "USAGE IN SECONDS",
                        SUM(ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE)/60.00 AS "USAGE IN MINUTES",  
                        ZSOURCE.ZDEVICEID AS "DEVICE ID (HARDWARE UUID)"
                    FROM ZOBJECT
                        LEFT JOIN ZSOURCE ON ZOBJECT.ZSOURCE = ZSOURCE.Z_PK
                            WHERE ZSTREAMNAME = ?
                                AND date(DATETIME((ZOBJECT.ZSTARTDATE+978307200),'UNIXEPOCH', 'LOCALTIME')) = date('now')
                                AND ZSOURCE.ZDEVICEID IS NOT NULL
                            GROUP BY ZOBJECT.ZVALUESTRING
                            ORDER BY SUM(ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE) DESC
                    """, ("/app/usage",))

        rows = cur.fetchall()

        # Connect to Screentime.db to get the user-facing app names
        SCREENTIME_DB_PATH = os.environ['SCREENTIME_DB_PATH']
        db = sqlite3.connect(SCREENTIME_DB_PATH, check_same_thread=False)
        cursor = db.cursor()

        # Prepare the variables to be populated in the html template
        apps = []
        minutes = []
        total = 0
        
        # For each bundle_id in the top 7 by screen time:
        for row in rows[:7]:
            # Add its screen time to the list of screen time values
            minutes.append(round(row[2]))
            # Query the Screentime database to get its user-facing app name 
            cursor.execute("""SELECT APPNAME FROM app_name WHERE BUNDLEID = ?""", (row[0],))
            results = cursor.fetchall()

            # If there is no user-facing app name in the db, fetch it from the iTunes API and add it to the db
            if not all(results[0]): 
                try:
                    url = f"http://itunes.apple.com/GB/lookup?bundleId={row[0]}"
                    response = requests.get(url)
                    response_dict = response.json()

                    try:
                        app_name = response_dict["results"][0]["trackName"]
                        # Remove special characters from the app name
                        clean_name = app_name.translate(str.maketrans('', '', string.punctuation))
                        results[0][0] = clean_name
                        cursor.execute("""UPDATE app_name SET APPNAME = ? WHERE BUNDLEID = ?""", (clean_name, row[0]))
                        db.commit()
                    except:
                        results = [("Unknown app",)]

                except(requests.RequestException, ValueError, KeyError, IndexError):
                    print("error")

            apps.append(results[0])

        # Add up total screen time for the day
        for row in rows:
            total += round(row[2])

        db.close()
    
        # Flatten list of lists
        apps = [item for sublist in apps for item in sublist]

    # Fill html template with dynamic values
    html = render_template(
         "chart.html",
        title="Today's screen time in minutes",
        labels=apps,
        values=minutes,
        total=total
    )

    # Write rendered html to file
    with open("static/index.html", "w") as out_file:
        out_file.write(html)

    # Get the day of the last time the Telegram bot alert was sent
    last_run = datetime.fromtimestamp(os.path.getmtime("telegrambot_alerts.txt"))
    now = datetime.now()
    
    # If there has been more than 2 hours of screentime today and if the Telegram bot alert hasn't already been sent, send the alert
    if (total > 120) and (last_run.date() < now.date()):
        TOKEN = os.environ['BOT_TOKEN']
        chat_id = os.environ['CHAT_ID']
        message= f"Oh no! your partner has spent more than 2 hours on their phone today. They have spent the most time on {apps[0]} ({minutes[0]} minutes), {apps[1]} ({minutes[1]} minutes) and {apps[2]} ({minutes[2]} minutes). Don't hesitate to give them a gentle nudge to stop scrolling."
        url = f"https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={chat_id}&text={message}"
        print(requests.get(url).json())
        
        # Capture the timestamp for when the alert was sent to the Telegram bot alert log file
        with open("telegrambot_alerts.txt", "w") as f:
            f.write(str(datetime.now()))

    return "ok"




