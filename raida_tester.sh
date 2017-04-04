#!/usr/bin/env bash
# 
# Created: 2017-3-20, A-Lang
# 

# Variables
testcoin="testcoin.stack"
raida_nums=25
_REST_='\033[0m'
_GREEN_='\033[32m'
_RED_='\033[31m'
_BOLD_='\033[1m'
CURL_CMD="curl"
CURL_OPT="-qSfs"
JQ_CMD="jq"


# Don't change the following lines
WORKDIR="$( cd $( dirname "$0" ) && pwd )"
RUNNINGOS=$(`echo uname` | tr '[a-z]' '[A-Z]')
RUNNINGARCH=$(`echo uname -m` | tr '[a-z]' '[A-Z]')


# Strings
string_01="Could not Check hints because get_ticket service failed to get a ticket. Fix get_ticket first."
string_02="Loading test coin : $WORKDIR/$testcoin"
string_03="Checking ticket..."
string_04="Empty ticket"
string_05="HTTPS Access No Response"
error_01="Error: Testcoin File Not Found ($WORKDIR/$testcoin)"
error_02="Error: Invalid Command"
error_03="Error: Test Coin File seems to be Wrong Format ($WORKDIR/$testcoin)"
error_04="Error: Ticket Check Failed "
error_05="Error: Test failed, run the echo to see more details."
error_06="Error: Test failed, run the detect to see more details."
error_07="Error: Test failed, run the get_ticket to see more details."


Show_logo(){
    printf  '
              ________                ________      _
             / ____/ /___  __  ______/ / ____/___  (_)___
            / /   / / __ \/ / / / __  / /   / __ \/ / __ \
           / /___/ / /_/ / /_/ / /_/ / /___/ /_/ / / / / /
           \____/_/\____/\__,_/\__,_/\____/\____/_/_/ /_/

'
}

Show_head(){
    clear
    Show_logo
    cat <<EOF
#############################################################################
# Welcome to RAIDA Tester. A CloudCoin Consortium Opensource.               #
# The Software is provided as is, with all faults, defects and errors, and  #
# without warranty of any kind.                                             #
# You must have an authentic CloudCoin .stack file called 'testcoin.stack'  #
# in the same folder as this program to run tests.                          #
# The test coin will not be written to.                                     #
#############################################################################
EOF
}

Show_menu(){
    cat <<EOF
===================================
RAIDA Tester Commands Available:
[+] echo       (e)
[+] detect     (d)
[+] get_ticket (g)
[+] hints      (h)
[+] quit       (q)
EOF

}

Error(){
    message="$1"
    message_color="$_RED_$message$_REST_"
    echo -e "$message_color\n"
}

Show_requirement(){
    cat <<EOF
NOTE: The following packages must be already installed on the system.
 * Curl
 * Jq (see more details on https://stedolan.github.io/jq/)

Recommend: To install these packages, you can run the commands:
 yum install curl
 or
 apt-get install curl
  
EOF
}

Main()
{
    input=""
    while [ "$input" != "quit" ]
    do
        Show_menu

        echo -n "RAIDA Tester> " && read input
        if [ "$input" == "echo" -o "$input" == "e" ];then
            Process_request _echo

        elif [ "$input" == "detect" -o "$input" == "d" ];then
            Process_request _detect

        elif [ "$input" == "get_ticket" -o "$input" == "g" ];then
            Process_request _get_ticket

        elif [ "$input" == "hints" -o "$input" == "h" ];then
            Process_request _hints

        elif [ "$input" == "quit" -o "$input" == "q" ];then
            break

        else
            Error "$error_02"
        fi
    done
}


Check_requirement(){
    is_pass=1
    
    [ $(which $JQ_CMD) ] || is_pass=0

    if [ $is_pass -eq 0 ];then
        Show_requirement
        exit 1
    fi
}

Timer(){
	if [ "$RUNNINGOS" == "LINUX" ];then
		seconds=`date +%s%N`
	else
		seconds=`ruby -e 'puts "%.9f" % Time.now' | tr -d '.'`
	fi
	echo $seconds 
}

Get_denom(){
    sn=$1
    denom=0
    if [ $sn -gt 0 -a $sn -lt 2097153 ];then
        denom=1
    elif [ $sn -lt 4194305 ];then
        denom=5
    elif [ $sn -lt 6291457 ];then
        denom=25
    elif [ $sn -lt 14680065 ];then
        denom=100
    elif [ $sn -lt 16777217 ];then
        denom=250
    fi
    echo $denom
}


Process_request(){
    input=""
    option="$1"

    case "$option" in
        _echo)
        PROMPT="ECHO"
        ;;
        _detect)
        PROMPT="DETECT"
        ;;
        _get_ticket)
        PROMPT="GET_TICKET"
        ;;
        _hints)
        PROMPT="HINTS"
        ;;
        *)
        PROMPT="XXX"
        ;;
    esac

    while [ "$input" != "$raida_nums" ]
    do
        echo "What RAIDA# do you want to test $PROMPT? Enter 25 to end."
        echo -n "$PROMPT> " && read input
        if [ $input -ge 0 -a $input -lt 25  ];then
            $option $input

        elif [ "$input" = "$raida_nums" ];then
            break

        else
            Error "$error_02"

        fi
    done
}

_echo()
{
    echo_retval=0
    input="$1"
    raida="raida$input"
    raida_url="https://$raida.cloudcoin.global/service/echo"
    start_s=$(Timer)
    http_response=$($CURL_CMD $CURL_OPT $raida_url 2>&1)
    http_retval=$?
    end_s=$(Timer)
    elapsed=$(( (end_s-start_s)/1000000 ))

    if [ $http_retval -eq 0 ]; then
        status=$(echo $http_response | $JQ_CMD -r '.status')
    else
        status="error"
        echo_retval=1
    fi

    if [ "$status" == "ready" ];then
        status_color="$_GREEN_$status$_REST_"
        response_color="$_GREEN_$http_response$_REST_"
    else
        status_color="$_RED_$status$_REST_"
        response_color="$_RED_$http_response$_REST_"
        echo_retval=1
    fi

    echo
    echo -e "Status: $_BOLD_$status_color"
    echo "Milliseconds: $elapsed"
    echo "Request: $raida_url"
    echo -e "Response: $response_color"
    echo
    return $echo_retval
}


_detect(){
    # Check the local testcoin file
    Load_testcoin
    is_testcoin=$?
    [ $is_testcoin -eq 1 ] && return 1  # testcoin file not found or with wrong format

    input="$1"
    raida="raida$input"
    raida_url="https://$raida.cloudcoin.global/service/detect"
    nn=`$JQ_CMD '.cloudcoin[].nn' $testcoin | tr -d '"'`
    sn=`$JQ_CMD '.cloudcoin[].sn' $testcoin | tr -d '"'`
    string_an=`$JQ_CMD -r '.cloudcoin[].an[]' $testcoin`
    array_an=( $string_an )
    an="${array_an[$input]}"
    denom=$(Get_denom $sn)

    # Test the Echo
    test_echo=$(_echo $input)
    run_echo=$?
    if [ $run_echo -eq 1 ];then
        Error "$error_05"
        return 1
    fi 
            
    detect_retval=0
    raida_url="$raida_url?nn=$nn&sn=$sn&an=$an&pan=$an&denomination=$denom"
    start_s=$(Timer)
    http_response=$($CURL_CMD $CURL_OPT $raida_url 2>&1)
    http_retval=$?
    end_s=$(Timer)
    elapsed=$(( (end_s-start_s)/1000000 ))

    if [ $http_retval -eq 0 ]; then
        status=$(echo $http_response | $JQ_CMD -r '.status')
    else
        status="error"
        detect_retval=1
    fi

    if [ "$status" == "pass" ];then
        status_color="$_GREEN_$status$_REST_"
        response_color="$_GREEN_$http_response$_REST_"
    else
        status_color="$_RED_$status$_REST_"
        response_color="$_RED_$http_response$_REST_"
        detect_retval=1
    fi
            
    echo
    echo -e "Status: $_BOLD_$status_color"
    echo "Milliseconds: $elapsed"
    echo "Request: $raida_url"
    echo -e "Response: $response_color"
    echo
    return $detect_retval

}


_get_ticket(){
    # Check the local testcoin file
    Load_testcoin
    is_testcoin=$?
    [ $is_testcoin -eq 1 ] && return 1  # testcoin file not found or with wrong format

    input="$1"
    raida="raida$input"
    raida_url="https://$raida.cloudcoin.global/service/get_ticket"
    nn=`$JQ_CMD '.cloudcoin[].nn' $testcoin | tr -d '"'`
    sn=`$JQ_CMD '.cloudcoin[].sn' $testcoin | tr -d '"'`
    string_an=`$JQ_CMD -r '.cloudcoin[].an[]' $testcoin`
    array_an=( $string_an )
    an="${array_an[$input]}"
    denom=$(Get_denom $sn)

    # Test the Echo
    test_echo=$(_echo $input)
    run_echo=$?
    if [ $run_echo -eq 1 ];then
        Error "$error_05"
        return 1
    fi 

    # Test the Detect
    test_detect=$(_detect $input)
    run_detect=$?
    if [ $run_detect -eq 1 ];then
        Error "$error_06"
        return 1
    fi 
    
    get_ticket_retval=0        
    raida_url="$raida_url?nn=$nn&sn=$sn&an=$an&pan=$an&denomination=$denom"
    start_s=$(Timer)
    http_response=$($CURL_CMD $CURL_OPT $raida_url 2>&1)
    http_retval=$?
    end_s=$(Timer)
    elapsed=$(( (end_s-start_s)/1000000 ))

    if [ $http_retval -eq 0 ]; then
        status=$(echo $http_response | $JQ_CMD -r '.status')
    else
        status="error"
        get_ticket_retval=1
    fi
            
    if [ "$status" == "ticket" ];then
        status_color="$_GREEN_$status$_REST_"
        response_color="$_GREEN_$http_response$_REST_"
    else
        status_color="$_RED_$status$_REST_"
        response_color="$_RED_$http_response$_REST_"
        get_ticket_retval=1
    fi
            
    echo
    echo -e "Status: $_BOLD_$status_color"
    echo "Milliseconds: $elapsed"
    echo "Request: $raida_url"
    echo -e "Response: $response_color"
    echo
    return $get_ticket_retval

}


_hints(){
    Load_testcoin
    is_testcoin=$?
    [ $is_testcoin -eq 1 ] && return 1  # testcoin file not found or with wrong format

    input="$1"
    raida="raida$input"
    nn=`$JQ_CMD '.cloudcoin[].nn' $testcoin | tr -d '"'`
    sn=`$JQ_CMD '.cloudcoin[].sn' $testcoin | tr -d '"'`
    string_an=`$JQ_CMD -r '.cloudcoin[].an[]' $testcoin`
    array_an=( $string_an )
    an="${array_an[$input]}"
    denom=$(Get_denom $sn)
    raida_url="https://$raida.cloudcoin.global/service/get_ticket"
    raida_url="$raida_url?nn=$nn&sn=$sn&an=$an&pan=$an&denomination=$denom"

    # Test the Echo
    test_echo=$(_echo $input)
    run_echo=$?
    if [ $run_echo -eq 1 ];then
        Error "$error_05"
        return 1
    fi 

    # Test the Detect
    test_detect=$(_detect $input)
    run_detect=$?
    if [ $run_detect -eq 1 ];then
        Error "$error_06"
        return 1
    fi 

    # Test the Get_ticket
    test_get_ticket=$(_get_ticket $input)
    run_get_ticket=$?
    if [ $run_get_ticket -eq 1 ];then
        Error "$error_07"
        return 1
    fi 

    echo "$string_03"
    Obtain_ticket $raida_url
    Obtain_ticket_retval=$?
    hints_retval=0
            
    if [ $Obtain_ticket_retval -eq 0 ]; then
        echo "Last ticket is: $ticket"
        raida_url="https://$raida.cloudcoin.global/service/hints"
        raida_url="$raida_url?rn=$ticket"
        start_s=$(Timer)
        http_response=$($CURL_CMD $CURL_OPT $raida_url 2>&1)
        http_retval=$?
        end_s=$(Timer)
        elapsed=$(( (end_s-start_s)/1000000 ))

        if [ $http_retval -eq 0 ]; then
            _sn=$(echo $http_response | cut -d: -f1)
            _ms=$(echo $http_response | cut -d: -f2)
            status="Success, The serial number was $_sn and the ticket age was $_ms milliseconds old."
            status_color="$_GREEN_$status$_REST_"
            response_color="$_GREEN_$http_response$_REST_"
        else
            status="error"
            status_color="$_RED_$status$_REST_"
            response_color="$_RED_$http_response$_REST_"
            hints_retval=1
        fi

        echo
        echo -e "Status: $_BOLD_$status_color"
        echo "Milliseconds: $elapsed"
        echo "Request: $raida_url"
        echo -e "Response: $response_color"
        echo

    else
        hints_retval=1
    fi

    return $hints_retval
}

Obtain_ticket(){
    raida_url="$1"
    http_response=$($CURL_CMD $CURL_OPT $raida_url 2>&1)
    is_raida=$(echo $http_response | grep -c "server")

    if [ "$is_raida" == "1" ];then
        message="$(echo $http_response | $JQ_CMD -r '.message')"
        status="$(echo $http_response | $JQ_CMD -r '.status')"

        if [ $status != "ticket" ];then
            ticket=""
            echo "Last ticket is: empty"
            echo
            echo -e "$_RED_$string_01$_REST_"
            echo -e "Status: $_BOLD_$_RED_$status$_REST_"
            echo "Request: $raida_url"
            echo "Response: $http_response"
            echo
            return 1

        else
            ticket="$message"
            return 0

        fi
    else
        echo
        echo -e "$_BOLD_$_RED_$string_05$_REST_"
        echo "Request: $raida_url"
        echo
        return 1

    fi
}


Load_testcoin(){
    if [ -f $testcoin ];then
        $JQ_CMD '.cloudcoin' $testcoin >/dev/null 2>&1
        is_json=$? 
        if [ $is_json -eq 0 ];then # Is JSON
            echo -e "$string_02"
            return 0
        else # Not JSON
            Error "$error_03"
            return 1
        fi
    else
        Error "$error_01"
        return 1
    fi
}


cd $WORKDIR
Check_requirement
Show_head
Main

exit
