#! /usr/bin/env python3

import sys

DISC_TEMP_VALUES = [9999]
KEEP_QUAL_VALUES = [0, 1, 4, 5, 9]

def parse(line):
    try:
        timestamp = int(line[15:23])
        recd_temp = int(line[87:92])
        recd_qual = int(line[92])
    except (ValueError, IndexError) as e:
        return

    if recd_temp in DISC_TEMP_VALUES:
        return

    if recd_qual not in KEEP_QUAL_VALUES:
        return

    print('{0}\t{1}'.format(timestamp, recd_temp))


for line in sys.stdin:
    parse(line.strip())
