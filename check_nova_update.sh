#!bin/sh

#the script can check the status of the processes of nova after update
#operation.
#If the service is installed,the script will check the status of
#service process at first to see whether the process exists.
#Then the script will check service process' restart time to see whether
#it restarted in last 10min.
#At last it will check the error information in the process log file.


# Set up default directories.The script will check whether the logfile exists
# in LOG_DIR_DEFAULT.If not, it will check LOG_DIR
LOG_DIR_DEFAULT=/var/log/nova
LOG_DIR=/data/log/nova

check_process_status(){
    #check whether the process exists
    pid=`ps -e -O etime|grep ${service}|grep -v grep|awk 'NR==1{print $1}'`
        #if pid is empty, the process doesn't exist
    if [ "${pid}" == "" ];then
        echo -e "\033[31mERROR: ${service} didn't start. \033[0m"
        return 1
    else
        echo -e "pid num:\t ${pid}"
    fi

    #check the start time of process is no longer than 10 min
    elapseTime=`ps -e -O etimes|grep ${pid}|grep -v 'grep'|awk \
    '{printf($2)}'`

    #if the process doesn't exist,then elapseTime is empty
    if [ ${elapseTime} -gt 600 ];then
        echo -e "\033[31mERROR: start time of ${service} is ${elapseTime} seconds ago. \033[0m"
        return 1
    else
        echo -e "elapsed time:\t ${elapseTime}"
    fi
    return 0
}


check_process_log(){
        #find the row number of the last restart flag "=========="
        #nova-api flag is different from others,
        echo -e "logfile:\t ${NOVA_SERVICE_LOG_PATH}"
        if [ ${service} == "nova-api-os-compute" ];then
            rownum=`nl $NOVA_SERVICE_LOG_PATH|tac|sed -n '/Loading app osapi_compute.*$/{p;q}'|awk '{print$1}'`
        elif [ ${service} == "nova-api-metadata" ];then
            rownum=`nl $NOVA_SERVICE_LOG_PATH|tac|sed -n '/Loading app metadata.*$/{p;q}'|awk '{print$1}'`
        elif [ ${service} == "nova-novncproxy" ];then
            return
        else
            rownum=`nl $NOVA_SERVICE_LOG_PATH|tac|sed -n '/======================.*$/{p;q}'|awk '{print$1}'`
        fi

        if [ "${rownum}" == "" ];then
            echo -e "\033[31mERROR: Cant find the start mark \033[0m"
        fi

        echo -e "logStartLine: \t ${rownum}"

        errorCount=`sed -n ''$rownum',$p'  $NOVA_SERVICE_LOG_PATH| grep -E "ERROR|TRACE nova"| wc -l`

        echo -e "errorCount: \t $errorCount"

        if [ ${errorCount} -gt 0 ];then
            echo -e "\033[31mERROR: ${service} didnt start correctly according to the log \033[0m"

            errorLog=`sed -n ''$rownum',$p' $NOVA_SERVICE_LOG_PATH|grep -E\
                      "ERROR|TRACE nova"`
            echo -e "\033[31mERROR log: \n${errorLog} \033[0m"
        else
            echo -e "Log start status: \t correctly"
        fi
}

check_nova_services(){
    echo "Service to be checked: $@"
    for service in $@;do
        echo
        echo "-------------------------------------"
        echo "             $service                "
        echo "-------------------------------------"
        #check whether the service is installed on this host
        if [[ -n "`which ${service} 2>/dev/null`" ]]; then
            echo "${service} has been installed"
            #check whether the service is running and the elapseTime of it
            check_process_status ${service}

            status=$?

            if [ $status -ne 0 ];then
                continue
            fi

            if [ -f ${LOG_DIR_DEFAULT}/${service}.log ];then
                NOVA_SERVICE_LOG_PATH=${LOG_DIR_DEFAULT}/${service}.log
                check_process_log $NOVA_SERVICE_LOG_PATH

            elif [ -f ${LOG_DIR}/${service}.log ];then

                NOVA_SERVICE_LOG_PATH=${LOG_DIR}/${service}.log
                check_process_log $NOVA_SERVICE_LOG_PATH

            else
                echo -e "\033[31mERROR: ${service} logfile doesn't exist \033[0m"
            fi
        else
            echo "${service} hasn't been installed"

        fi
    done
}

check_nova_services "nova-api-metadata" "nova-api-os-compute" "nova-compute"  "nova-scheduler" "nova-novncproxy" "nova-consoleauth" "nova-dhcpbridge" "nova-network"
