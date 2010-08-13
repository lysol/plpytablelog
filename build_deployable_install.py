
from optparse import OptionParser


def main():
    parser = OptionParser('usage: %prog inputfile')
    parser.add_option('-e','--escaped', dest="escaped", 
        action="store_true", default=False, help="Enable to escape the " + \
        "output as if it was going into a non-dollar quoted field.")
    (options, args) = parser.parse_args()
    
    out_lines = []

    # Since Functions can't have SELECT statements that don't send results
    # somewhere, we have to replace them with PERFORM.
    perform_transforms = (
        'SELECT logging.build_setup();',
        'SELECT logging.deploy();',
        )

    def process_file(file_name):
        """Function intended for recursive use to include \i files in psql
        scripts."""
        in_source = open(file_name, 'r')
        for line in in_source.readlines():
            if line.strip()[:2] == '\i':
                next_file = line.strip()[3:].strip()
                process_file(next_file)
            else:
                appended = None
                for trans in perform_transforms:
                    if trans in line:
                        out_lines.append(line.replace('SELECT', 'PERFORM'))
                        appended = True
                if not appended:
                    out_lines.append(line)
    if len(args) == 1:
        source_file = args[0]
    else:
        source_file = 'logging.install.sql'
    process_file(source_file)

    text = "            ".join(out_lines)

    text = """
        CREATE OR REPLACE FUNCTION logging_install() RETURNS VOID AS $INSTALL$
            BEGIN
            IF (
                SELECT 'logging' IN (
                    SELECT nspname
                    FROM pg_catalog.pg_namespace
                    )
               ) THEN RETURN;
            END IF;
            --BEGIN
    """ + text + """
            --EXCEPTION WHEN OTHERS THEN
            --    RETURN;
            --END;
            END;
            $INSTALL$ LANGUAGE plpgsql VOLATILE;
            SELECT logging_install();
    """
    if options.escaped:
        print text.replace("\n", "\\n").replace("'", "\\'")
    else:
        print text

if __name__ == "__main__":
    main()
