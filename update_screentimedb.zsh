#!/bin/zsh

# updates the screentime database with the Screen Time stats for the past 6 days
# updates the app_name table with the list of bundle ids (apps) used in the past 28 days
# you can set this up to run daily with a cron job

sqlite3 <path/to/your/KnowledgeC.db> << 'EOF'
ATTACH "<path/to/your/screentime.db>" AS screentime;
INSERT OR IGNORE INTO screentime (zobject_table_id, start, end, bundle_id, usage_seconds, usage_minutes, device_id, day, entry_creation)
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
      ZSTREAMNAME = "/app/usage" 
      AND date(DATETIME((ZOBJECT.ZSTARTDATE+978307200),'UNIXEPOCH', 'LOCALTIME')) = date('now', '-6 day');
INSERT OR IGNORE INTO screentime.app_name (BUNDLEID) 
SELECT 
      DISTINCT ZVALUESTRING
   FROM ZOBJECT
   WHERE
      ZSTREAMNAME = "/app/usage";
EOF
