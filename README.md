NRPE script that produces warnings/critical levels when hits in Elasticsearch reaches certain thresholds.

Example:
/usr/lib64/nagios/plugins/check_logstash_count -c 10 -w 5 -q "level:ERROR"