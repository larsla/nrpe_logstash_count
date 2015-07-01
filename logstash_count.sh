#!/bin/bash

function show_help {
    echo "Usage: $0 <OPTIONS>"
    echo "  -q <query> == query that will be inserted in to the query template (eg: level:ERROR)"
    echo "  -H <host> == query another elasticsearch host than localhost"
    echo "  -t <template file> == use another template for the elasticsearch query"
    echo "  -d <tempdir> == use some other directory than /tmp/.logstash_count.. mostly for development"
    echo "  -v == verbose"
}

export VERBOSE=0
export QUERY=""
export HOST="localhost"
export TEMPLATE_FILE=""
export TEMPDIR="/tmp/.logstash_count"

while getopts "h?q:h:d:v" opt; do
    case "$opt" in
    v)
        VERBOSE=1
        ;;
    q)
        QUERY=$OPTARG
        ;;
    H)
        HOST=$OPTARG
        ;;
    t)
        TEMPLATE_FILE=$OPTARG
        ;;
    d)
        TEMPDIR=$OPTARG
        ;;
    h|\?)
        show_help
        exit 0
        ;;
    esac
done

if [ -z "$QUERY" ]; then
    echo "You have to provide a query!"
    exit -1
fi

QUERY_NAME=`echo $QUERY |sed 's/[^a-zA-Z0-9]/_/g'`

if [ $TEMPLATE_FILE ]; then
	if [ -f $TEMPLATE_FILE ]; then
		TEMPLATE=`cat $TEMPLATE_FILE`
	else
		echo "$TEMPLATE_FILE must be a file containing a proper elasticsearch query template"
		exit -1
	fi
else
	TEMPLATE='{
    "query": {
        "filtered" : {
            "query" : {
                "query_string" : {
                    "query" : "__QUERY__"
                }
            },
            "filter" : {
                "range" : { "@timestamp": { "gte": "__LASTRUN__" } }
            }
        }
    }
}'
fi

mkdir -p /tmp/.logstash_count
NOW=`date +%FT%T.000%:z`
TS=`date +%s`

LASTRUN_FILE="${TEMPDIR}/${QUERY_NAME}"
if [ -f $LASTRUN_FILE ]; then
        LASTRUN=`cat $LASTRUN_FILE`
else
        LASTRUN=$NOW
fi

QUERYFILE="${TEMPDIR}/${TS}.json"

echo $TEMPLATE > $QUERYFILE
sed -ri "s/__QUERY__/${QUERY}/" $QUERYFILE
sed -ri "s/__LASTRUN__/${LASTRUN}/" $QUERYFILE

echo $NOW > $LASTRUN_FILE

OUTPUT=`curl -s -XGET 'http://localhost:9200/logstash-*/logs/_count' -d @${QUERYFILE}`
RC=$?

if [ $RC -eq 0 ]; then
	COUNT=`echo $OUTPUT |jq '.count'`

	echo $COUNT
else
	echo "Something went wrong with querying elasticsearch"
fi
rm $QUERYFILE

exit $RC
