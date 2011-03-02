
from optparse import OptionParser
import os

def main():
    parser = OptionParser('usage: %prog inputfile')

    parser.add_option("-n", "--no-function", dest="nofunction",
        action="store_true", help="Don't generate the script as a function.")
    (options, args) = parser.parse_args()
    
    out_lines = []

    if len(args) != 1:
        print "Usage: %s" % parser.usage
        print "Missing argument"
        exit(1)

    # Since Functions can't have SELECT statements that don't send results
    # somewhere, we have to replace them with PERFORM.
    perform_transforms = (
        'SELECT logging.build_setup();',
        'SELECT logging.deploy();',
        )

    def process_file(file_name):
        """Function intended for recursive use to include \i files in psql
        scripts."""
        in_source = open(os.path.expanduser(file_name), 'r')
        for line in in_source.readlines():
            if line.strip()[:2] == '\i':
                next_file = line.strip()[3:].strip()
                process_file(next_file)
            else:
                appended = None
                if not options.nofunction:
                    for trans in perform_transforms:
                        if trans in line:
                            out_lines.append(line.replace('SELECT', 'PERFORM'))
                            appended = True
                if not appended:
                    out_lines.append(line)
    
    source_file = args[0]
    
    process_file(source_file)

    text = "".join(out_lines)

    if not options.nofunction:
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
    else:
        text = "BEGIN;\n%s\nCOMMIT;" % text
    print text

if __name__ == "__main__":
    main()
