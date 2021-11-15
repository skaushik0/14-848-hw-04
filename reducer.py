#! /usr/bin/env python3

import sys

prev_timestamp, max_temp = None, 0

def compute(line):
    global prev_timestamp
    global max_temp

    parts = line.split()

    if len(parts) != 2:
        return

    try:
        timestamp = int(parts[0])
        recd_temp = int(parts[1])
    except ValueError:
        return

    if prev_timestamp and (prev_timestamp != timestamp):
        print(prev_timestamp, max_temp)
        prev_timestamp, max_temp = timestamp, recd_temp
    else:
        prev_timestamp, max_temp = timestamp, max(max_temp, recd_temp)


for line in sys.stdin:
    compute(line.strip())

if prev_timestamp:
    print(prev_timestamp, max_temp)
