CREATE OR REPLACE FUNCTION logging.size() RETURNS integer AS $$

/*
    logging.size()
    
    Returns the size, in bytes, of all log tables combined.
    
    ~ DRA
*/


DECLARE 
    v_size_bucket INTEGER DEFAULT 0;
    m_row RECORD;
BEGIN
    FOR m_row IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'logging'
    LOOP
        v_size_bucket = v_size_bucket + pg_relation_size('logging.' || m_row.table_name);
    END LOOP;
RETURN v_size_bucket;
END;

$$ LANGUAGE plpgsql VOLATILE;
