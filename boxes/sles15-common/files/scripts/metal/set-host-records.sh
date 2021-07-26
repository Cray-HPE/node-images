#!/usr/bin/env bash

# get the host_records from cloud-init
data=$(craysys metadata get host_records|jq)

HOST_PATH="/etc/"
HOST_FILE="hosts"
hosts=$HOST_PATH$HOST_FILE

# getting number of records
number_of_entries=$(echo $data |jq .[].ip|wc -l)

for (( i=0; i<$number_of_entries; i++ ))
do
    alias=""
    # get record ip
    host_ip=$(echo $data|jq  -r .[${i}].ip)
    # get number of aliases of a record
    number_of_aliases=$(echo $data|jq  .[${i}].aliases[]|wc -l)

    if [ "$number_of_aliases" -gt "0" ]
    then
       for (( j=0; j<$number_of_aliases; j++ ))
       do
          alias+="	$(echo $data|jq -r .[${i}].aliases[${j}])"
       done
    else
       echo "no aliase for $host"
    fi

    single_hostname=$(echo $alias|cut -d ' ' -f1)
    check_ip=$(echo $hosts|grep $host_ip|wc -l)
    check_hostname=$(cat $hosts|grep $single_hostname |wc -l)

    # add an entry if no ip and no hostname in /etc/hosts
    if [ "$check_hostname" -eq "0" ] && [ "$check_ip" -eq "0" ] && [ ! -z "$host_ip" ] && [ ! -z "$alias" ]
    then
        echo "$host_ip$alias" >> $hosts
    fi

    # if there are previous entries in /etc/hosts, entry is removed and cloud-init will be added
    if [ "$check_hostname" -gt "0" ] || [ "$check_ip" -gt "0" ] && [ ! -z "$host_ip" ] && [ ! -z "$alias" ]
    then
        sed -i  "/$host_ip/ d" $hosts
        sed -i  "/$single_hostname/ d" $hosts
        echo "$host_ip$alias" >> $hosts
    fi
done
