#!/bin/zsh

# connects to the KnowledgeC.db on the user's Mac. The KnowledgeC.db is typically found at /Users/{user}/Library/Application\ Support/Knowledge/knowledgeC.db 
# creates the screentime db (if the db doesn't yet exist at that path, this query will create it)
# populates the screentime.db and table with your Screen Time information the KnowledgeC.db
# creates the app_name table to host the bundle id - app name mapping

sqlite3 <path/to/your/KnowledgeC.db> << 'EOF'
ATTACH "<path/to/your/screentime.db>" AS screentime;
INSERT INTO screentime (zobject_table_id, start, end, bundle_id, usage_seconds, usage_minutes, device_id, day, entry_creation)
SELECT
      ZOBJECT.Z_PK AS "ZOBJECT TABLE ID", 
      DATETIME(ZOBJECT.ZSTARTDATE+978307200,'UNIXEPOCH', 'LOCALTIME') AS "START", 
      DATETIME(ZOBJECT.ZENDDATE+978307200,'UNIXEPOCH', 'LOCALTIME') AS "END",
      ZOBJECT.ZVALUESTRING AS "BUNDLE ID", 
      (ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE) AS "USAGE IN SECONDS",
      (ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE)/60.00 AS "USAGE IN MINUTES",  
      ZSOURCE.ZDEVICEID AS "DEVICE ID (HARDWARE UUID)", 
      CASE ZOBJECT.ZSTARTDAYOFWEEK 
         WHEN "1" THEN "Sunday"
         WHEN "2" THEN "Monday"
         WHEN "3" THEN "Tuesday"
         WHEN "4" THEN "Wednesday"
         WHEN "5" THEN "Thursday"
         WHEN "6" THEN "Friday"
         WHEN "7" THEN "Saturday"
      END "DAY OF WEEK",
      DATETIME(ZOBJECT.ZCREATIONDATE+978307200,'UNIXEPOCH', 'LOCALTIME') AS "ENTRY CREATION"
   FROM ZOBJECT
      LEFT JOIN
         ZSOURCE 
         ON ZOBJECT.ZSOURCE = ZSOURCE.Z_PK 
   WHERE
      ZSTREAMNAME = "/app/usage";
INSERT INTO screentime.app_name (BUNDLEID) 
SELECT 
      DISTINCT ZVALUESTRING
   FROM ZOBJECT
   WHERE
      ZSTREAMNAME = "/app/usage";
EOF
