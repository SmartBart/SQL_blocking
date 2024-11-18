IF OBJECT_ID('tempdb..#Blocks') IS NOT NULL
    DROP TABLE #Blocks
SELECT   spid
        ,blocked
        ,REPLACE (REPLACE (st.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS batch
INTO     #Blocks
FROM     sys.sysprocesses spr
CROSS APPLY sys.dm_exec_sql_text(spr.SQL_HANDLE) st
GO

WITH BlockingTree (spid, blocking_spid, [level], batch)
AS
(
    SELECT   blc.spid
            ,blc.blocked
            ,CAST (REPLICATE ('0', 4-LEN (CAST (blc.spid AS VARCHAR))) + CAST (blc.spid AS VARCHAR) AS VARCHAR (1000)) AS [level]
            ,blc.batch
    FROM    #Blocks blc
    WHERE   (blc.blocked = 0 OR blc.blocked = SPID)
    AND     EXISTS (SELECT * FROM #Blocks blc2 WHERE blc2.BLOCKED = blc.SPID AND blc2.BLOCKED <> blc2.SPID)
    UNION ALL
    SELECT   blc.spid
            ,blc.blocked
            ,CAST(bt.[level] + RIGHT (CAST ((1000 + blc.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS [level]
            ,blc.batch
    FROM     #Blocks AS blc
    INNER JOIN BlockingTree bt ON blc.blocked = bt.SPID
    WHERE   blc.blocked > 0
    AND     blc.blocked <> blc.SPID
)
SELECT N'' + ISNULL(REPLICATE (N'|         ', LEN (LEVEL)/4 - 2),'')
        + CASE WHEN (LEN(LEVEL)/4 - 1) = 0 THEN '' ELSE '|------  ' END
        + CAST (bt.SPID AS NVARCHAR (10)) AS BlockingTree
        ,spr.lastwaittype   AS [Type]
        ,spr.loginame       AS [Login Name]
        ,st.text            AS [SQL Text]
        ,DB_NAME(spr.dbid)  AS [Database]
        ,spr.cmd            AS [Command]
        ,spr.waitresource   AS [Wait Resource]
        ,spr.program_name   AS [Application]
        ,spr.hostname       AS [HostName]
        ,spr.last_batch     AS [Last Batch Time]
FROM BlockingTree bt
LEFT OUTER JOIN sys.sysprocesses spr ON spr.spid = bt.spid
CROSS APPLY sys.dm_exec_sql_text(spr.SQL_HANDLE) st
ORDER BY LEVEL ASC
