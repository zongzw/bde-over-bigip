#!/bin/bash

# NOT WORKS NOW BECAUSE THERE ARE '\' IN docs/http.logging.irule

cdir=`cd $(dirname $0); pwd`
workdir=$cdir/../..
command_prefix="curl -s -k -u admin:admin"

# env 
. $workdir/conf.d/.setup.rc # temp

# irule_content=`cat $workdir/docs/http.logging.irule | sed ':a;N;s/\n/\\\\n/g;ta' | sed 's/"/\\\\"/g'`
# echo $irule_content

# deploy with as3
vs_name=sample_application
body=`cat << EOF
{
    "class": "AS3",
    "action": "deploy",
    "targetHost": "$BIGIP_MGMT_IPADDR",
    "targetUsername": "$BIGIP_MGMT_USERNAME",
    "targetPassphrase": "$BIGIP_MGMT_PASSWORD",
    "declaration": {
        "class": "ADC",
        "schemaVersion": "3.0.0",
        "id": "container",
        "label": "Sample 1 in a container",
        "remark": "Simple HTTP application with RR pool",
        "$vs_name": {
            "class": "Tenant",
            "A1": {
                "class": "Application",
                "template": "http",
                "serviceMain": {
                    "class": "Service_HTTP",
                    "virtualPort": $FAKE_BIGIP_VS_PORT,
                    "virtualAddresses": [
                        "$FAKE_BIGIP_VS_IPADDR"
                    ],
                    "pool": "web_pool"
                },
                "web_pool": {
                    "class": "Pool",
                    "loadBalancingMode": "least-connections-node",
                    "monitors": [
                        "http"
                    ],
                    "members": [
                        {
                            "servicePort": $FAKE_BIGIP_VS_SERVICEPORT,
                            "serverAddresses": $FAKE_BIGIP_VS_POOL
                        }
                    ]
                }
            }
        }
    }
}
EOF
`

# don't create logging pool here.
# ,
#                  "logging_pool": {
#                     "class": "Pool",
#                     "monitors": [
#                         "icmp"
#                     ],
#                     "members": [
#                         {
#                             "servicePort": 20001,
#                             "serverAddresses": $FAKE_BIGIP_VS_POOL
#                         }
#                     ]
#                 }

# don't create irule for the fake bigip vs.
# ,
#                     "iRules": [
#                         "f5-logging-irule"
#                     ]

# ,
#                 "f5-logging-irule": {
#                     "class": "iRule",
#                     "iRule": "\n\n$irule_content"
#                 }
#echo $body

echo -n "Creating virtual server ... "
$command_prefix -H "Content-Type: application/json" \
    -s -o "%{http_code}" \
    -X POST https://as3:443/mgmt/shared/appsvcs/declare \
    -d "$body"
echo

# check vs ok.
# for first time:
# # ./setup-bigip-vs.sh
# {"version":"3.16.0","release":"6","schemaCurrent":"3.16.0","schemaMinimum":"3.0.0"}
# {"id":"83ef9b32-2cf3-45e7-a86d-7715e8b7d475","results":[{"message":"Installing service discovery components. The results of your request may be retrieved by sending a GET request to selfLink provided.","tenant":"","host":"","runTime":0,"code":0}],"declaration":{},"selfLink":"https://localhost/mgmt/shared/appsvcs/task/83ef9b32-2cf3-45e7-a86d-7715e8b7d475"}

echo -n "Waiting for virtual server created ... " 
wait=0
timeout=60
while [ $wait -lt $timeout ]; do
    curl -k -s -u $BIGIP_MGMT_USERNAME:$BIGIP_MGMT_PASSWORD https://$BIGIP_MGMT_IPADDR:$BIGIP_MGMT_PORT/mgmt/tm/ltm/virtual | grep "$vs_name/$FAKE_BIGIP_VS_IPADDR" > /dev/null
    if [ $? -eq 0 ]; then 
        echo "$vs_name/$FAKE_BIGIP_VS_IPADDR [Done]"
        break
    else 
        echo -n '.'
    fi
    wait=$(($wait + 1))
    sleep 1
done

if [ $wait -ge $timeout ]; then echo "Failed to create $vs_name/$FAKE_BIGIP_VS_IPADDR"; fi
