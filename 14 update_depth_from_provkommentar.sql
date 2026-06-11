-- =============================================================================
-- update_depth_from_provkommentar.sql
--
-- Updates MIN_PROVDJUP_M and MAX_PROVDJUP_M in INTERIM_SAMPLES where:
--   • Both depth columns are 'MISSING'
--   • PROVKOMMENTAR contains the string 'djup' (case-insensitive)
--   • A numeric value can be extracted from PROVKOMMENTAR
--
-- Extraction strategy:
--   SQLite lacks regex, so extraction is performed by locating the first
--   run of digit/decimal characters in PROVKOMMENTAR.  The script works
--   by finding the position of the first digit (0-9) and then using
--   SUBSTR to pull characters from that position onward, trimming at the
--   first non-numeric character.
--
--   Because SQLite has no loop construct, a fixed-length SUBSTR (up to 10
--   characters) is taken from the first digit position and then the
--   trailing non-numeric suffix is stripped with nested REPLACE / TRIM.
--   This handles integers and decimals with either '.' or ',' as the
--   separator (comma is normalised to period before CAST).
--
--   Rows where no digit is found are left untouched (first-digit position
--   returns 0 for all ten INSTR checks).
--
-- After a successful update PROVKOMMENTAR has " depth updated" appended.
-- =============================================================================

-- ── Helper view: locate the first digit in PROVKOMMENTAR ─────────────────────
-- We test for each digit 0-9 individually and take the minimum non-zero
-- position.  A position of 0 means that digit is absent.

-- =============================================================================
-- Preview: inspect what will be updated before committing
-- =============================================================================
SELECT
    ROWID,
    PROVKOMMENTAR,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    -- First-digit position for each possible leading digit
    CASE
        WHEN MIN(
            CASE WHEN INSTR(PROVKOMMENTAR,'0')>0 THEN INSTR(PROVKOMMENTAR,'0') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'1')>0 THEN INSTR(PROVKOMMENTAR,'1') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'2')>0 THEN INSTR(PROVKOMMENTAR,'2') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'3')>0 THEN INSTR(PROVKOMMENTAR,'3') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'4')>0 THEN INSTR(PROVKOMMENTAR,'4') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'5')>0 THEN INSTR(PROVKOMMENTAR,'5') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'6')>0 THEN INSTR(PROVKOMMENTAR,'6') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'7')>0 THEN INSTR(PROVKOMMENTAR,'7') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'8')>0 THEN INSTR(PROVKOMMENTAR,'8') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'9')>0 THEN INSTR(PROVKOMMENTAR,'9') ELSE 9999 END
        ) < 9999
        THEN
            CAST(
                REPLACE(
                    -- strip everything from the first non-numeric, non-decimal character onward
                    -- by taking up to 10 chars and trimming trailing letters/spaces
                    TRIM(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        REPLACE(REPLACE(
                            SUBSTR(
                                PROVKOMMENTAR,
                                MIN(
                                    CASE WHEN INSTR(PROVKOMMENTAR,'0')>0 THEN INSTR(PROVKOMMENTAR,'0') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'1')>0 THEN INSTR(PROVKOMMENTAR,'1') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'2')>0 THEN INSTR(PROVKOMMENTAR,'2') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'3')>0 THEN INSTR(PROVKOMMENTAR,'3') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'4')>0 THEN INSTR(PROVKOMMENTAR,'4') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'5')>0 THEN INSTR(PROVKOMMENTAR,'5') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'6')>0 THEN INSTR(PROVKOMMENTAR,'6') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'7')>0 THEN INSTR(PROVKOMMENTAR,'7') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'8')>0 THEN INSTR(PROVKOMMENTAR,'8') ELSE 9999 END,
                                    CASE WHEN INSTR(PROVKOMMENTAR,'9')>0 THEN INSTR(PROVKOMMENTAR,'9') ELSE 9999 END
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
            AS REAL)
        ELSE NULL
    END AS extracted_depth
FROM INTERIM_SAMPLES
WHERE
    MIN_PROVDJUP_M = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND UPPER(PROVKOMMENTAR) LIKE '%DJUP%'
ORDER BY ROWID;


-- =============================================================================
-- UPDATE: apply depth extraction
-- Uses a WITH clause (CTE) to compute the first-digit position once, then
-- updates only rows where a valid numeric depth was found.
-- =============================================================================

WITH depth_candidates AS (
    SELECT
        ROWID,
        PROVKOMMENTAR,
        -- position of the first digit in the comment
        MIN(
            CASE WHEN INSTR(PROVKOMMENTAR,'0')>0 THEN INSTR(PROVKOMMENTAR,'0') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'1')>0 THEN INSTR(PROVKOMMENTAR,'1') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'2')>0 THEN INSTR(PROVKOMMENTAR,'2') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'3')>0 THEN INSTR(PROVKOMMENTAR,'3') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'4')>0 THEN INSTR(PROVKOMMENTAR,'4') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'5')>0 THEN INSTR(PROVKOMMENTAR,'5') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'6')>0 THEN INSTR(PROVKOMMENTAR,'6') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'7')>0 THEN INSTR(PROVKOMMENTAR,'7') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'8')>0 THEN INSTR(PROVKOMMENTAR,'8') ELSE 9999 END,
            CASE WHEN INSTR(PROVKOMMENTAR,'9')>0 THEN INSTR(PROVKOMMENTAR,'9') ELSE 9999 END
        ) AS first_digit_pos
    FROM INTERIM_SAMPLES
    WHERE
        MIN_PROVDJUP_M  = 'MISSING'
        AND MAX_PROVDJUP_M = 'MISSING'
        AND UPPER(PROVKOMMENTAR) LIKE '%DJUP%'
),
depth_extracted AS (
    SELECT
        ROWID,
        PROVKOMMENTAR,
        first_digit_pos,
        -- extract up to 10 characters from the first digit, then strip
        -- everything that is not a digit or decimal point/comma
        CAST(
            REPLACE(
                TRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    REPLACE(REPLACE(
                        SUBSTR(PROVKOMMENTAR, first_digit_pos, 10),
                    ' ','X'),'m','X'),'M','X'),'c','X'),'C','X'),
                    'd','X'),'D','X'),'j','X'),'J','X'),'u','X'),
                    'p','X'),'P','X'),'r','X'),'R','X'),'o','X'),
                    'O','X'),'v','X'),'V','X'),'t','X'),'T','X'),
                    'x',''),
                    'X','')
                )
            , ',', '.')
        AS REAL) AS depth_value
    FROM depth_candidates
    WHERE first_digit_pos < 9999
)
UPDATE INTERIM_SAMPLES
SET
    MIN_PROVDJUP_M = CAST((SELECT depth_value FROM depth_extracted WHERE depth_extracted.ROWID = INTERIM_SAMPLES.ROWID) AS TEXT),
    MAX_PROVDJUP_M = CAST((SELECT depth_value FROM depth_extracted WHERE depth_extracted.ROWID = INTERIM_SAMPLES.ROWID) AS TEXT),
    PROVKOMMENTAR  = PROVKOMMENTAR || ' depth updated'
WHERE
    INTERIM_SAMPLES.ROWID IN (
        SELECT ROWID FROM depth_extracted WHERE depth_value IS NOT NULL AND depth_value > 0
    );


-- =============================================================================
-- Verification: review updated rows
-- =============================================================================
SELECT
    ROWID,
    MIN_PROVDJUP_M,
    MAX_PROVDJUP_M,
    PROVKOMMENTAR
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR LIKE '% depth updated'
ORDER BY ROWID;


-- =============================================================================
-- Summary counts
-- =============================================================================
SELECT
    'Updated (depth extracted)'  AS status,
    COUNT(*)                     AS n_rows
FROM INTERIM_SAMPLES
WHERE PROVKOMMENTAR LIKE '% depth updated'

UNION ALL

SELECT
    'Still MISSING after update (djup present but no digit found)',
    COUNT(*)
FROM INTERIM_SAMPLES
WHERE
    MIN_PROVDJUP_M  = 'MISSING'
    AND MAX_PROVDJUP_M = 'MISSING'
    AND UPPER(PROVKOMMENTAR) LIKE '%DJUP%';
