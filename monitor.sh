#!/bin/bash

TIMEOUT=600
IFACE=eth0
TIMESTAMP=`date +%b_%d_%Y_%H_%M_%S`
OUTPUT=/var/log/nethogs/$TIMESTAMP.log

sh -ic "{ /usr/sbin/nethogs $IFACE >>$OUTPUT; \
kill 0; } | { sleep $TIMEOUT; \
kill 0; }"
