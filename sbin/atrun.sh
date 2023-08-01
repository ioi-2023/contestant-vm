#!/bin/sh

# 2020-09-13 19:00 2020-09-14 00:00 3 /opt/ioi/sbin/contest.sh prep 0

SCHEDULE="/opt/ioi/misc/schedule2.txt"

TIMENOW=$(date +"%Y-%m-%d %H:%M")

schedule()
{
	# XXX 

	logger -p local0.info "ATRUN: Scheduling next job $JOBID at $NEXTTIME"
}

execute()
{
	JOBID=$1
	JOB=$(cat $SCHEDULE | head -$JOBID | tail -1)
	ENDTIME=$(echo "$JOB" | cut -d\  -f3,4)
	if ! echo "$ENDTIME" | grep -q '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\s[0-9]\{2\}:[0-9]\{2\}'; then
		ENDTIME="9999-12-31 23:59"
	fi
	if [ "$TIMENOW" \> "$ENDTIME" ]; then
		NEWJOBID=$(echo "$JOB" | cut -d\  -f5)
		logger -p local0.info "ATRUN: Job $JOBID is over, jumping to $NEWJOBID"
		schedule $NEWJOBID
	else
		CMD=$(echo "$JOB" | cut -d\  -f6-)
		logger -p local0.info "ATRUN: Run job $JOBID now: $CMD"
		$CMD
		NEWJOBID=$((JOBID+1))
		schedule $NEWJOBID
	fi
}

case "$1" in
	schedule)
		logger -p local0.info "ATRUN: Restart scheduling"
		schedule 1
		;;
	next)
		;;
	exec)
		execute $2
		;;
	*)
esac
# vim: ft=sh ts=8 noet
