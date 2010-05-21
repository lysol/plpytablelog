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

source_file = 'logging.install.sql'
process_file(source_file)

text = "            ".join(out_lines)

text = """
    CREATE OR REPLACE FUNCTION logging_install() RETURNS VOID AS $INSTALL$
        BEGIN
        BEGIN
""" + text + """
        EXCEPTION WHEN OTHERS THEN
            RETURN;
        END;
        END;
        $INSTALL$ LANGUAGE plpgsql VOLATILE;
        SELECT logging_install();
"""

print text
