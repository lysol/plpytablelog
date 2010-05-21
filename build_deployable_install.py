out_lines = []

def process_file(file_name):
    """Function intended for recursive use to include \i files in psql
    scripts."""
    in_source = open(file_name, 'r')
    for line in in_source.readlines():
        if line.strip()[:2] == '\i':
            next_file = line.strip()[3:].strip()
            process_file(next_file)
        else:
            out_lines.append(line)

source_file = 'logging.install.sql'
process_file(source_file)

print "".join(out_lines)
