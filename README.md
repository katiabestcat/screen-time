# Screen Time
Break your phone addiction with the Screen Time accountability tool 


## Description: 
Do you spend more time on your phone than you would like? Have you tried using Screen Time app limits and other Screen Time management apps, only to turn them off to keep scrolling? With this application you can share your daily phone usage stats with a friend or partner, so that they can help you manage your phone addiction!

Current features:
- your chosen accountability partner can see how much you used your phone today in (almost) real time in a web dashboard
- they will also receive a Telegram alert when you go over a set phone usage threshold

Then your partner can hopefully give you some gentle encouragement to stop scrolling, or maybe just knowing that they can see your phone usage at any time will be motivating enough!


## How it works
The main application in app.py queries KnowledgeC.db, the local SQLite database where Apple stores usage stats for your iPhone (and other Apple devices) on your Mac. Using Flask, app.py then renders a static html file locally (index.html), populated with the latest phone usage data queried from KnowledgeC. The html file uses JavaScript, Jinja templates and the Charts.js framework to display the Screen Time information for the day, with a breakdown by app for the top 7 apps. This dashboard is then deployed in production via Surge.sh 

app.py runs whenever there are changes to the KnowledgeC.db file, which updates on a regular basis when Apple devices are being used. These automated application runs are triggered thanks to Meta's Watchman open-source application, which allows you to monitor the device usage database file and trigger the main application script whenever it changes. 

The KnowledgeC file stores app names as bundle ids, which are not user facing. For example, it stores "Instagram" as "com.burbn.instagram". There is code in the main script to fetch the user-facing app name for each bundle id from the iTunes API and persist it in a SQLite table called app_name.

When the phone usage for the day goes over a certain limit (set to 2 hours in my case), the application triggers a Telegram alert to my accountability partner, using a dedicated Telegram bot. 

All the Screen Time history stays locally on your Mac, and only your latest Screen Time information is pushed to production via the web dashboard and the Telegram bot, to be shared with your accountability partner. 


## Step-by-step implementation 
- Pre-requisites:
	- You will need to have both an iPhone and a Macbook or Mac desktop: the Mac is where you will be able to access the Screen Time information for your phone in the KnowledgeC.db file. 
	- You have to enable Screen Time and tick the sync Screen Time across your devices option on both your Mac and iPhone. This is so that your phone usage stats can be accessed and queried from your Mac, without having to jailbreak your own phone -- screenshot here. 
	- Once you enable the syncing across devices, you will be able find your Screen Time stats on your Mac, which Apple logs in the KnowledgeC.db file located in the Application Support folder. This database captures not only your Screen Time by application and device, but also extremely detailed data about your device usage more generally (apps opened, websites visited, geolocations, etc.) - a goldmine for law enforcement investigators! If you're curious about the content of KnowldegeC.db, [Mac4n6, a Mac and iOS digital forensics blog](https://www.mac4n6.com/blog/2018/8/5/knowledge-is-power-using-the-knowledgecdb-database-on-macos-and-ios-to-determine-precise-user-and-application-usage) maintained by Sarah Edwards provides a thorough overview of the database schema, which would otherwise seem fairly cryptic to us. You can use a tool like the [DB browser for SQLite](https://sqlitebrowser.org) to browse the data in the database.
- Dependencies
	- for this project you will need to install
		- [Flask](https://flask.palletsprojects.com/en/3.0.x/): a light-weight Python web framework that will generate the usage dashboard html. See instructions for installation at [this link](https://flask.palletsprojects.com/en/3.0.x/installation/), including how to create a virtual environment for Python
		- [python-dotenv](https://github.com/theskumar/python-dotenv#readme): this allows you to read environment variables from a .env file, which we'll use to store your Telegram bot token, Telegram chat id and the paths to your SQLite databases.  To install it, simply run `$ pip3 install python-dotenv` in your Terminal. You can see an example .env file in .env_example
		- [Watchman](https://facebook.github.io/watchman/): this tool will monitor the KnowledgeC device usage database and trigger the main application in app.py whenever the database is updated so that an up-to-date phone usage dashboard can be generated. You can install it with Homebrew on MacOS: `$ brew update` and  `$ brew install watchman`
		- [Surge](https://surge.sh): this will allow you to deploy your html dashboard into production from the command line. You'll find installation instructions [here](https://surge.sh/help/getting-started-with-surge) 
	- If you want to send alerts to your accountability partner via Telegram, you'll have to create a Telegram bot - instructions [here](https://www.cytron.io/tutorial/how-to-create-a-telegram-bot-get-the-api-key-and-chat-id). Make sure to take note of your bot token and of the chat id you have with your accountability partner and fill them in the .env file. The main app.py script will monitor your daily phone usage and send out a Telegram alert to your partner when it goes over 2 hours.
- Installation
	1.  clone this repository to the folder where you store your projects: `$ git clone https://github.com/katiabestcat/screen-time-tracker.git`
	2. you might need to grant Full Disk access to the applications that need to access the KnowledgeC database file in the Application Support folder (for example your code editor, the Terminal and Watchman)
	3. open the repository folder: `$ cd Screentime`
	4. then create the screentime database and app_name table that will store the mapping between the bundle ids and the app user-facing names by running create_screentimedb.zsh. First make this shell script executable by running `$ chmod a+x create_screentimedb.zsh`, then execute it: `$ ./create_screentimedb.zsh`
		- this script also creates the screentime table, which will store your Screen Time stats over time (Apple only stores your stats for the past 28 days by default, so this table will allow you to store it for longer, and analyse trends over time if you wish)
		- you can set up a daily cron job to run the database update script (update_screentimedb.zsh): 
			- first make the script executable: `$ chmod a+x update_screentimedb.zsh`
			- then set up a cron job to run it every day: `$ crontab -e` to edit your cron jobs, then enter this line, if you want to run it, say, at 11.59pm every day: 
			`59 23 * * * /path/to/update_screentimedb.zsh` 
	5. in the .env_example file, fill in the paths to your KnowledgeC and screentime databases, as well as your Telegram bot token and chat id.
	6. cd into the folder where your KnowledgeC.db resides:
		- `cd /Users/{user}/Library/Application\ Support/Knowledge/knowledgeC.db`
		- make the run_app script executable: `chmod a+x <path/to/your/project/folder/run_app.zsh>`
		- set up Watchman to watch the file and trigger the script when it changes: `watchman-make -p '**/*.db' --run <path/to/your/project/folder/run_app.zsh>`
	7. finally, cd into the static folder of your repository, where the html file is located, and run Surge, appending your custom domain name if you wish: 
	      `$ cd <path/to/your/project/folder/Screentime/static>`
	      `$ surge --domain https://custom.domain.name.surge.sh`


## Known issues and limitations
- the application relies on Apple's KnowledgeC.db, which we don't control. If Apple decides to change the schema or anything else in a future iOS/MacOS release, it will probably break the app as it is and necessitate a code update. 
- the syncing of Screen Time across devices, especially between iPhone and Mac can be [somewhat temperamental](https://www.forbes.com/sites/gordonkelly/2023/08/05/apple-ios-16-ipados-16-iphone-ipad-bug-screentime-bug-new-iphone-problem/), with a significant lag at times. 
- the phone usage web dashboard relies on the Mac being active, so you have to leave your Mac up and running during the time you use your phone. 


## Design decisions
- The design of this project was a bit tricky because we rely on a third party database, which is stored and updated locally, on the Mac. And we need to display the Screen Time information from the database to an accountability partner in production, outside of the local environment. So unlike other light web applications, I couldn't just deploy the application on third party platforms like Render using the PosgreSQL database they usually provide for independent developers. I considered creating an API for the database, that would somehow send the Screen Time information to a web server in production, but the SQLite documentation discourages this, for [performance and reliability reasons](https://sqlite.org/draft/useovernet.html): they recommend keeping the application in the same environment as the SQLite file. Hence the design choice of running the application locally, creating an html file on the machine, then deploying only the html into production with Surge.sh. An alternative approach (maybe for a future iteration) would be to generate a data json locally, with the results of the database query, then push it to Render on a regular basis, very similar to what Andrej Karpathy did for [ulogme](https://github.com/karpathy/ulogme).
- File watching: I tried using [lsyncd](https://github.com/lsyncd/lsyncd) initially, instead of Watchman, but lsyncd doesn't seem to work for Macs any longer (see the [corresponding issue](https://github.com/lsyncd/lsyncd/issues/204#issuecomment-1794164518))
- Privacy: one could choose to only display the overall Screen Time, instead of the breakdown by app, if one wishes to have more privacy and avoid showing usage of potentially problematic / confidential apps, like dating apps or worse :p. You can also easily edit the content of the Telegram message to remove the app information and only share the aggregate Screen Time. 


## Other existing, similar projects
- rud.is's analysis of Mac desktop usage using KnowledgeC.db, R and D3: [link here](https://rud.is/b/2019/10/28/spelunking-macos-screentime-app-usage-with-r/)
- Karpathy analysis of desktop usage by logging keystrokes: [ulogme](http://karpathy.github.io/2014/08/03/quantifying-productivity/)
- Screen Time management apps - Freedom, Present, Opal, ...I've tried many of them.  To the best of my knowledge, they don't allow you to share Screen Time information with an accountability partner. This might be because of Apple's app sandboxing, which prevents app developers from sharing data outside of the user's device without some kind of transformation on it. 


## Credits 
- to the CS50 staff for making an amazing course that enabled me to make this application