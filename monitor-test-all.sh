#!/bin/bash# Dump script to keep monitoring and have record of any outage greaterthan interval during geo-ha failovers
# It will report change of CNAME record due to Route53 failover policy
# output could be redirected to a file just > monitor.txt 
#

if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]; then  
  echo "Usage: monitor-test-all-geo <manage namespace> [interval secs]"  
  echo "Example:"  
  echo "     bash monitor-test-all-geo.sh manage.example.com"  
  echo "     bash monitor-test-all-geo.sh manage.example.com 1 >example.com.log"  
  echo ""  
  exit -1
fi

MANAGE=$1
INSECURE=""
CNAME=""
if [ -z "$2" ]; then
        INTERVAL=5
        else 
        INTERVAL=$2
fi

echo "trying https..."
nc $MANAGE 443 -w1
 if [ $? -eq 0 ]; then
          PROTO="https://"        
          echo "https -> OK"        
          curlresult=`curl "$PROTO$MANAGE/testall" 2> /dev/null`
          if [ $? -eq 60 ]; then                
          INSECURE="-k"                
          echo "Warning: certificate error. Trying insecureconnection..."        
          fi
else
        echo "trying http..." 
        nc $MANAGE 80 -w1        
        if [ $? -eq 0 ]; then
                 PROTO="http://"                
                 echo "http -> OK"        
        else               
                 echo "network error"  
                 exit 1        
        fi
fi

echo "Testing $PROTO$MANAGE/testall $INSECURE"
curlresult=`curl "$PROTO$MANAGE/testall" -s $INSECURE`
echo "Response from endpoint: $curlresult"
if [ "$curlresult" != "OK" ]; then        
        echo "Endpoint error. Cancelling..."        
        exit 1
fi

echo ""
echo "date/time, availability, details"
while [ true ]
do        
        DATETIME=`date -u "+%Y%m%dZ%H:%M:%S"`
        TESTALLRESULT=`curl "$PROTO$MANAGE/testall" -s $INSECURE`
        if [[ $TESTALLRESULT == OK ]] ; then 
                AVAILABILITY=1                
                DETAILS=$TESTALLRESULT
                
        elif  [[ $TESTALLRESULT == *doctype* ]] ; then
                   AVAILABILITY=1
                   DETAILS="auth0-probe-endpoints signaling LB"       
        else                
                  AVAILABILITY=0          
                  DETAILS=`echo "$TESTALLRESULT" | tr '\n' ' '`        
        fi

        echo "$DATETIME, $AVAILABILITY, $DETAILS"  
        DIGRESULT=`dig $MANAGE -t CNAME +noall +cmd +answer |grep -e^manage |awk '{print $5}'`  
        if [ "$CNAME" != "$DIGRESULT" ]; then      
        echo "CNAME now set to $DIGRESULT !!!!"          
          CNAME="$DIGRESULT"      
        fi        
        # echo ""
        
        
        
        
        sleep $INTERVAL
done
