# Set up default directories
LOG_DIR_DEFAULT=/var/log
LOG_DIR=/data/log

check_process_status(){
    #check whether the process exists
    pid=`ps -ef -O etime|grep $@|grep -v grep|awk 'NR==1{print $1}'`
        #if pid is empty, the process doesn't exist
    if [ "${pid}" == "" ];then
        echo -e "\033[31mERROR: ${service} didn't start. \033[0m"
        return 1
    else
        echo -e "pid num:\t ${pid}"
    fi
   

    #check the start time of process is no longer than 10 min
    elapseTime=`ps -ef -O etimes|grep ${pid}|grep -v 'grep'|awk \
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
        echo -e "logfile:\t ${NOVA_SERVICE_LOG_PATH}"
 
        rownum=`nl $NOVA_SERVICE_LOG_PATH|tac|sed -n '/=============================.*$/{p;q}'|awk '{print$1}'`
        errorCount=`awk 'NR>$rownum' $NOVA_SERVICE_LOG_PATH | grep "error" |wc -l`  
        
        #errorCount may be null
        if [ ${errorCount} -gt 0 ];then
            echo -e "\033[31mERROR: ${service} didnt start correctly according to the log \033[0m"
        else
            echo -e "start status: \t correctly"
        fi
}

check_nova_services(){
    echo $@
    for service in $@;do
        echo
        echo "*************************************"
        echo "             $service                "
        echo "*************************************"
        #check whether the service is installed on this host
        if [[ -n "`which ${service} 2>/dev/null`" ]]; then
            echo "${service} has been installed"
            #check whether the service is running and the elapseTime of it
            check_process_status ${service}
            
            status=$?

            if [ $status -ne 0 ];then
                continue               
            fi 


            if [ -f ${LOG_DIR_DEFAULT}/nova/${service}.log ];then
                NOVA_SERVICE_LOG_PATH=${LOG_DIR_DEFAULT}/nova/${service}.log 
                check_process_log $NOVA_SERVICE_LOG_PATH
            
            elif [ -f ${LOG_DIR}/nova/${service}.log ];then
                NOVA_SERVICE_LOG_PATH=${LOG_DIR}/nova/${service}.log 
                check_process_log $NOVA_SERVICE_LOG_PATH
            
            else
                echo -e "\033[31mERROR: ${service} logfile doesn't exist \033[0m"
            fi
        fi
    done
}

check_nova_services "nova-compute" "nova-conductor"  "nova-scheduler" "nova-api"

