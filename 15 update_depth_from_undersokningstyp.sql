-- =============================================================================
-- update_depth_from_undersokningstyp.sql
--
-- Updates MIN_PROVDJUP_M and MAX_PROVDJUP_M in INTERIM_SAMPLES where:
--   • Both depth columns are 'MISSING'
--   • UNDERSOKNINGSTYP contains at least one digit
--   • A valid positive numeric value can be extracted
--
-- Extraction strategy (same approach as update_depth_from_provkommentar.sql):
--   Locate the first digit in UNDERSOKNINGSTYP, take a 10-character window
--   from that position, strip all non-numeric characters, normalise decimal
--   comma to period, and CAST to REAL.
--
-- PROVKOMMENTAR handling:
--   • If PROVKOMMENTAR = 'MISSING'  → replace with 'depth updated from UNDERSOKNINGSTYP'
--   • Otherwise                     → append ' depth updated from UNDERSOKNINGSTYP'
-- =============================================================================


-- =============================================================================
-- Preview: inspect what will be updated before committing
-- =============================================================================
SELECT
    ROWID,
    UNDERSOKNINGSTYP,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    PROVKOMMENTAR,
    CAST(
        REPLACE(
            TRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(
                    SUBSTR(
                        UNDERSOKNINGSTYP,
                        MIN(
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'0')>0 THEN INSTR(UNDERSOKNINGSTYP,'0') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'1')>0 THEN INSTR(UNDERSOKNINGSTYP,'1') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'2')>0 THEN INSTR(UNDERSOKNINGSTYP,'2') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'3')>0 THEN INSTR(UNDERSOKNINGSTYP,'3') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'4')>0 THEN INSTR(UNDERSOKNINGSTYP,'4') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'5')>0 THEN INSTR(UNDERSOKNINGSTYP,'5') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'6')>0 THEN INSTR(UNDERSOKNINGSTYP,'6') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'7')>0 THEN INSTR(UNDERSOKNINGSTYP,'7') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'8')>0 THEN INSTR(UNDERSOKNINGSTYP,'8') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'9')>0 THEN INSTR(UNDERSOKNINGSTYP,'9') ELSE 9999 END
                        ),
                        10
                    ),
                ' ','X'),'m','X'),'M','X'),'c','X'),'C','X'),
                'd','X'),'D','X'),'j','X'),'J','X'),'u','X'),
                'p','X'),'P','X'),'r','X'),'R','X'),'o','X'),
                'O','X'),'v','X'),'V','X'),'t','X'),'T','X'),
                'x',''),
                'X','')
            )
        , ',', '.')
    AS REAL) AS extracted_depth
FROM INTERIM_SAMPLES
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND (
        INSTR(UNDERSOKNINGSTYP,'0') > 0 OR INSTR(UNDERSOKNINGSTYP,'1') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'2') > 0 OR INSTR(UNDERSOKNINGSTYP,'3') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'4') > 0 OR INSTR(UNDERSOKNINGSTYP,'5') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'6') > 0 OR INSTR(UNDERSOKNINGSTYP,'7') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'8') > 0 OR INSTR(UNDERSOKNINGSTYP,'9') > 0
    )
ORDER BY ROWID;


-- =============================================================================
-- UPDATE: apply depth extraction
-- =============================================================================

-- Note: SQLite CTEs cannot be used directly in UPDATE…SET subqueries in all
-- versions, so the extraction expression is written inline in the UPDATE.
-- The WHERE clause repeats the digit-presence check and the > 0 guard so
-- that rows where extraction yields NULL or 0 are never touched.

UPDATE INTERIM_SAMPLES
SET
    MIN_PROVDJUP_M = CAST(
        (
            SELECT
                REPLACE(
                    TRIM(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(
                            SUBSTR(
                                INTERIM_SAMPLES.UNDERSOKNINGSTYP,
                                MIN(
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'0')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'0') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'1')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'1') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'2')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'2') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'3')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'3') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'4')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'4') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'5')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'5') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'6')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'6') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'7')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'7') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'8')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'8') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'9')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'9') ELSE 9999 END
                                ),
                                10
                            ),
                        ' ','X'),'m','X'),'M','X'),'c','X'),'C','X'),
                        'd','X'),'D','X'),'j','X'),'J','X'),'u','X'),
                        'p','X'),'P','X'),'r','X'),'R','X'),'o','X'),
                        'O','X'),'v','X'),'V','X'),'t','X'),'T','X'),
                        'x',''),
                        'X','')
                    )
                , ',', '.')
        )
    AS TEXT),

    MAX_PROVDJUP_M = CAST(
        (
            SELECT
                REPLACE(
                    TRIM(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(
                            SUBSTR(
                                INTERIM_SAMPLES.UNDERSOKNINGSTYP,
                                MIN(
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'0')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'0') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'1')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'1') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'2')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'2') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'3')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'3') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'4')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'4') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'5')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'5') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'6')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'6') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'7')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'7') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'8')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'8') ELSE 9999 END,
                                    CASE WHEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'9')>0 THEN INSTR(INTERIM_SAMPLES.UNDERSOKNINGSTYP,'9') ELSE 9999 END
                                ),
                                10
                            ),
                        ' ','X'),'m','X'),'M','X'),'c','X'),'C','X'),
                        'd','X'),'D','X'),'j','X'),'J','X'),'u','X'),
                        'p','X'),'P','X'),'r','X'),'R','X'),'o','X'),
                        'O','X'),'v','X'),'V','X'),'t','X'),'T','X'),
                        'x',''),
                        'X','')
                    )
                , ',', '.')
        )
    AS TEXT),

    PROVKOMMENTAR = CASE
        WHEN PROVKOMMENTAR = 'MISSING'
            THEN 'depth updated from UNDERSOKNINGSTYP'
        ELSE
            PROVKOMMENTAR || ' depth updated from UNDERSOKNINGSTYP'
    END

WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    -- at least one digit present
    AND (
        INSTR(UNDERSOKNINGSTYP,'0') > 0 OR INSTR(UNDERSOKNINGSTYP,'1') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'2') > 0 OR INSTR(UNDERSOKNINGSTYP,'3') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'4') > 0 OR INSTR(UNDERSOKNINGSTYP,'5') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'6') > 0 OR INSTR(UNDERSOKNINGSTYP,'7') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'8') > 0 OR INSTR(UNDERSOKNINGSTYP,'9') > 0
    )
    -- extracted value must be a valid positive number
    AND CAST(
        REPLACE(
            TRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REPLACE(REPLACE(
                    SUBSTR(
                        UNDERSOKNINGSTYP,
                        MIN(
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'0')>0 THEN INSTR(UNDERSOKNINGSTYP,'0') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'1')>0 THEN INSTR(UNDERSOKNINGSTYP,'1') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'2')>0 THEN INSTR(UNDERSOKNINGSTYP,'2') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'3')>0 THEN INSTR(UNDERSOKNINGSTYP,'3') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'4')>0 THEN INSTR(UNDERSOKNINGSTYP,'4') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'5')>0 THEN INSTR(UNDERSOKNINGSTYP,'5') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'6')>0 THEN INSTR(UNDERSOKNINGSTYP,'6') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'7')>0 THEN INSTR(UNDERSOKNINGSTYP,'7') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'8')>0 THEN INSTR(UNDERSOKNINGSTYP,'8') ELSE 9999 END,
                            CASE WHEN INSTR(UNDERSOKNINGSTYP,'9')>0 THEN INSTR(UNDERSOKNINGSTYP,'9') ELSE 9999 END
                        ),
                        10
                    ),
                ' ','X'),'m','X'),'M','X'),'c','X'),'C','X'),
                'd','X'),'D','X'),'j','X'),'J','X'),'u','X'),
                'p','X'),'P','X'),'r','X'),'R','X'),'o','X'),
                'O','X'),'v','X'),'V','X'),'t','X'),'T','X'),
                'x',''),
                'X','')
            )
        , ',', '.')
    AS REAL) > 0;


-- =============================================================================
-- Verification: review updated rows
-- =============================================================================
SELECT
    ROWID,
    UNDERSOKNINGSTYP,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    PROVKOMMENTAR
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR LIKE '%depth updated from UNDERSOKNINGSTYP'
ORDER BY ROWID;


-- =============================================================================
-- Summary counts
-- =============================================================================
SELECT
    'Updated (depth extracted from UNDERSOKNINGSTYP)' AS status,
    COUNT(*) AS n_rows
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR LIKE '%depth updated from UNDERSOKNINGSTYP'

UNION ALL

SELECT
    'Still MISSING (digit present in UNDERSOKNINGSTYP but extraction yielded 0 or NULL)',
    COUNT(*)
FROM INTERIM_SAMPLES
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND (
        INSTR(UNDERSOKNINGSTYP,'0') > 0 OR INSTR(UNDERSOKNINGSTYP,'1') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'2') > 0 OR INSTR(UNDERSOKNINGSTYP,'3') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'4') > 0 OR INSTR(UNDERSOKNINGSTYP,'5') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'6') > 0 OR INSTR(UNDERSOKNINGSTYP,'7') > 0 OR
        INSTR(UNDERSOKNINGSTYP,'8') > 0 OR INSTR(UNDERSOKNINGSTYP,'9') > 0
    );
