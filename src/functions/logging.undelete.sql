CREATE OR REPLACE FUNCTION logging.undelete(log_table_name varchar, orig_table_name varchar, orig_record_seq integer)
    RETURNS void AS $$
DECLARE
    i_query character varying;
    resultant character varying;
BEGIN
i_query := $Q$

        SELECT 'INSERT INTO ' ||
        $Q$ || quote_literal(quote_ident(orig_table_name::varchar)) || $Q$ || E' (\n' || 
        array_to_string(array_agg(quote_ident(column_name::varchar)), ', ')
         || E'\n) \nVALUES\n (\n' || 
        replace(array_to_string(
            array_agg(

                    quote_literal((

                        SELECT old_value
                        FROM logging.$Q$ || quote_ident(log_table_name) || $Q$ y 
                        WHERE record_seq = $Q$ || orig_record_seq || $Q$ 
                        AND y.table_name = ly.table_name 
                        AND y.column_name = ly.column_name
                        AND event = 'DELETE'
                        ORDER BY date_modified DESC
                        LIMIT 1
                    ))::varchar || '::' ||
                    (
                        SELECT data_type 
                        FROM information_schema.columns c
                        WHERE c.table_name = ly.table_name 
                        AND c.column_name = ly.column_name
                    )

            ),', '
            ) || E'\n);'::varchar, $x$'None'::$x$, 'NULL::')

FROM
    logging.$Q$ || quote_ident(log_table_name) || $Q$ ly
    WHERE record_seq = $Q$ || orig_record_seq || $Q$
    AND table_name = $Q$ || quote_literal(orig_table_name) || $Q$
    AND event = 'DELETE'
    AND seq = (
        SELECT max(seq) FROM logging.$Q$ || quote_ident(log_table_name) || $Q$
        WHERE record_seq = $Q$ || orig_record_seq || $Q$
        AND table_name = $Q$ || quote_literal(orig_table_name) || $Q$
        AND event = 'DELETE'
    )
    $Q$;
RAISE NOTICE '%', i_query;
EXECUTE i_query INTO resultant;
RAISE NOTICE 'Executing query: %', resultant;
EXECUTE resultant;
END;
$$ LANGUAGE PLPGSQL VOLATILE;
