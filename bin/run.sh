#!/bin/sh

HELP_RUN=$(cat <<- 'EOF'
\n  
run.sh  [OPTIONS]... [ARGS] \n
\n
通过properties配置文件, 固化本次测试中不怎个变的参数 \n 
有效参数项, 参考JMeter的*.properties文件。 \n
要求:  run.sh脚本必要的参数, 如:    -JThreads=?,        -JRampup=?,        -JDuration=?,        -JLoopOrRampupCount=? \n
要求:  JMX脚本必要的配置参数，如: ${__P(Threads, 1)}, ${__P(Rampup, 1)}, ${__P(Duration, 1)}, ${__P(LoopOrRampupCount, 1)} \n
\n

OPTIONS: \n
    -pnew 当前工作目录$PWD, 创建test.proerties配置文件。 此选项存在时，其他选项无效。
\n
    -p, -prop  <file> proerties配置文件，默认: test.proerties
\n \n
    -jmx  <file> 指定要运行的.jmx文件
\n \n
    -thd,-threads  <num> 指定运行或要达到的目标线程数
\n
    -rampup  <secs> 指定用于加载线程的时间
\n
    -duration  <secs> 指定加载完线程数后的持续运行时间
\n
    -c,-count  <LoopOrRampupCount> 指定每个线程运行的迭代次数或线程分几次加载
\n \n
    -nmon  [regex] 指定要监控的服务器(server.json文件中groupname, hostname, ip) 三项任一匹配即可。 本选项要求使用rssh_async程序和server.json配置文件。
\n
    -nmonident  [str] 搭建-nmon选项使用，默认为: perf,  一是作为查询nmon进程的标识符，二是在远程服务器上新建一个[str]目录存放每次测试生成的临时目录
\n \n
ARGS:  不在[OPIONTS]里的，全部转移到到jmeter命令行参数中, 用于临时的参数设置 \n
\n
例如: \n
默认(固定）线程组, 50线程1秒加载完成持续运行200秒，-1表达每个线程持续运行：\n
    ./run.sh -jmx fixed.jmx -thd 50 -rampup 1 -duration 200 -c -1 \n
\n
默认(固定）线程组, 同上，附加利用rssh_async监控远程服务器系统资源使用：\n
    ./run.sh -jmx fixed.jmx -thd 50 -rampup 1 -duration 200 -c -1 -nmon [regex] \n
\n
阶梯式线程组， 100线程，分10次在600秒内加载完成（每60秒加载1次，每个阶梯运行60秒），所有线程加载完成后持续运行5秒：\n
    ./run.sh -jmx steps.jmx -thd 100 -rampup 600 -duration 5 -c 10 \n
\n
阶梯式线程组，同上，附加传输其他自定义参数给jmeter：\n
    ./run.sh -jmx steps.jmx -thd 100 -rampup 600 -duration 1 -c 10 -Jname=value \n
\n
\n
注意: 中途停止jmeter运行，请运行$JMETER_HOME/bin目录下的shutdown.sh脚本 \n
另开页签，不要CTRL+C掉当前脚本运行。目的是让jmeter正常结束，可生成html报告。\n
若不需要html报告，可直接CTRL+C终止测试。\n
EOF
)


scriptdir=`dirname $0` 
curdir=$PWD

logfile="run.log"
# nmon相关的默认参数
nmonident="perf"
nmonregex="all"

function log() {
    case "$1" in
        "debug" ) level="DEBUG" ;;
        "info" ) level="INFO" ;;
        "warn" ) level="WARN" ;;
        "error" ) level="ERROR" ;;
        * ) log error "未知的日志级别" && exit 3 ;;
    esac
    shift
    local ts=`date "+%m-%d %H:%M:%S"`
    echo "$ts ${level} [run.sh] $@" >> $logfile
    echo "$ts ${level} [run.sh] $@"
}

if [ $# -eq 0 ]; then
    echo -e $HELP_RUN
    exit 1
fi

# 前置处理
# 清空本脚本的日志文件
echo '' > $logfile

# 处理脚本传入的参数
ScriptARGS=""
PropFile=""
JmxFile=""
NmonARGS=""

while [ $# -ne 0 ]
do
    name=""
    case "$1" in
        "-jmx" ) shift && JmxFile=$1 ;;

        "-prop" ) shift && PropFile=$1 ;;
        "-p" ) shift && PropFile=$1 ;;

        "-pnew" ) PropNew=true ;;

        "-threads" ) name="Threads" ;;
        "-thd" ) name="Threads" ;;

        "-rampup" ) name="Rampup" ;;

        "-duration" ) name="Duration" ;;

        "-count" ) name="LoopOrRampupCount" ;;
        "-c" ) name="LoopOrRampupCount" ;;

        "-nmon" ) 
            nmonswitch=true
            NmonARGS="$NmonARGS -nmon"
            shift && nmonregex=$1 
            NmonARGS="$NmonARGS $1"
            ;;

        "-nmonident" ) 
            NmonARGS="$NmonARGS -nmonident"
            shift && nmonident=$1
            NmonARGS="$NmonARGS $1"
            ;;

        * )  ScriptARGS="$ScriptARGS $1" ;;
    esac

    if [[ -n $name ]]; then
        shift
        ScriptARGS="$ScriptARGS -J${name}=$1"
        case "$name" in 
            "Rampup" ) rampup=$1 ;;
            "Duration" ) duration=$1 ;;
        esac
    fi

    shift
done

# 校验参数
if [ $PropNew ]; then 
    TestPropsFile="${scriptdir}/test.properties"
    if [[ -f $TestPropsFile ]]; then
        cp $TestPropsFile "${curdir}/"
        log info "已创建新的test.properties文件: cp $TestPropsFile ${curdir}/"
    else
        log error "${TestPropsFile}文件不存在，不能创建新的test.properties文件"
    fi
    exit 1
fi

log info "本次传入脚本相关的参数有: $ScriptARGS"
log info "本次传入处理nmon相关的参数有: $NmonARGS"

if [[ -z $JmxFile ]]; then
    error "缺少必要的参数: -jmx"
    exit 1
fi

# 读取proerties文件，去取注释行
# 把配置信息转为以"-Jname=value "字符串，用于jmeter命令的参数传递
PropARGS=""
if [[ -z $PropFile ]]; then
    PropFile="test.properties"
    log warn "未指定proerties配置文件，使用默认的配置文件名字: $PropFile"
fi
if [ ! -f $PropFile ]; then
    log error "${PropFile}配置文件不存在"
    exit 1
fi

for prop in `grep -v "#" < $PropFile | grep -v "grep"`
do
    PropARGS="$PropARGS -J$prop "
done
log info "本次properties文件的配置参数有：$PropARGS"
# log info "读取${PropFile}文件里的配置信息结束!!!"

JTLFile="res.jtl"
JTLZipFile="${JTLFile}.tar.gz"
JTLHtmlDir="res"
JMeterLog="jmeter.log"
ARGS="$PropARGS $ScriptARGS -n -t $JmxFile -l $JTLFile -e -o $JTLHtmlDir"
log info "本次的运行输入的参数是： $ARGS"

# 计算运行nmon程序的一些参数
monitor_duration=`expr $rampup + $duration`
monitor_duration=`expr $monitor_duration + 5`
log info "monitor_duration: $monitor_duration 增加了5秒jmeter的启动和停止时间"

monitor_interval=`expr $monitor_duration / 1440`
monitor_interval=`expr $monitor_interval + 1`
log info "monitor_interval: $monitor_interval"

monitor_count=`expr $monitor_duration / $monitor_interval`
log info "monitor_count: $monitor_count"


log info "运行前检查开始..."
if [ -d $JTLHtmlDir ]; then
    log warn "删除已存在的: $JTLHtmlDir"
    rm -rf $JTLHtmlDir
fi
if [ -f $JTLFile ]; then
    log warn "删除已存在的: $JTLFile"
    rm -rf $JTLFile
fi
if [ -f $JTLZipFile ]; then
    log warn "删除已存在的: $JTLZipFile"
    rm -rf $JTLZipFile
fi
if [ -f $JMeterLog ]; then
    log warn "删除已存在的: $JMeterLog"
    rm -rf $JMeterLog
fi


# 在远程服务器上查找指定标识的nmon，并kill掉。
# 若没有标识符nmonident，则Kill掉所有正在运行的nmon程序
# grep -v jmx 用于排除本脚本运行的进程
if [ $nmonswitch ]; then 
    if [[ -n $nmonident ]]; then
        rssh_args="-l $logfile $nmonregex exec ps -- -ef | grep $nmonident | grep nmon |grep -v jmx | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
    else
        rssh_args="-l $logfile $nmonregex exec ps -- -ef | grep nmon |grep -v jmx | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
    fi
    log info "杀掉远程服务器上可能正在运行的nmon程序开始..., 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "杀掉远程服务器上可能正在运行的nmon程序结束!!!"
fi

# "归档目录名字:月日-时分 格式命名"
output=`date "+%m%d-%H%M"`
if [ -d $output ]; then
    log warn "删除已存在${output}目录, 一分钟内发起两次测试, 大概率前一次测试为无效，故默认清除上一次的结果"
    rm -rf $output
fi
mkdir ${output}
log info "新建本地归档目录: ${output}, 其格式为: 月日-时分"

if [ $nmonswitch ]; then 
    nmon_dir="${output}/nmon"
    mkdir -p $nmon_dir
    log info "新建本地nmon文件的存放目录: ${nmon_dir}"

    if [[ -n $nmonident ]]; then
        remote_nmon_dir="${nmonident}/${output}"
    else
        remote_nmon_dir=${output}
    fi

    rssh_args="-l $logfile $nmonregex exec mkdir -- -p $remote_nmon_dir"
    log info "远程服务器上, 新建临时目录: ${remote_nmon_dir}, 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
fi

log info "运行前检查结束!!!"

if [ $nmonswitch ]; then 
    monitor_nmon_file="${remote_nmon_dir}/res.nmon"
    rssh_args="-l $logfile $nmonregex exec nmon -- -F $monitor_nmon_file -t -s $monitor_interval -c $monitor_count"
    log info "nmon监控发起开始..., 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "nmon监控发起结束!!!"
    echo ""
fi


log info "运行jmeter开始..."
# jmeter $ARGS >> $logfile 2>&1
jmeter $ARGS 
retcode=$?
log info "运行jmeter结束...，返回码: $retcode"

# 下载nmon文件
if [ $nmonswitch ]; then 
    rssh_args="-l $logfile $nmonregex get $monitor_nmon_file $nmon_dir"
    log info "下载远程服务器上的nmon文件开始..., 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "下载远程服务器上的nmon文件结束!!!"
fi

# 下载nmon文件成功后，删除服务器的临时目录
if [ $nmonswitch ]; then 
    res=`ls ${nmon_dir}/*res.nmon 2>/dev/null`
    if [ -n "$res" ]; then
        rssh_args="-l $logfile $nmonregex exec rm -- -rf ${remote_nmon_dir}"
        log info "监测${nmon_dir}目录中存在*res.nmon文件，删除远程服务器上临时目录开始..., 将执行命令: rssh_async ${rssh_args}"
        rssh_async $rssh_args
        log info "删除远程服务器上的临时目录结束!!!"
    else
        log error "监测${nmon_dir}目录中不存在*res.nmon文件，代表下载nmon文件失败，请检查后重新手工下载监控文件: ${monitor_nmon_file}, 本地的nmon临时目录里有: ${res}"
    fi
fi

# 归档
log info "临时归档开始..."
if [ -f $JMeterLog ]; then
    mv $JMeterLog $output
    log info "移动${JMeterLog}文件到临时归档目录: ${output}"
else
    log warn "${JMeterLog}文件不存在"
fi

if [ -d $JTLHtmlDir ]; then
    hasHtmlDir=true
    mv $JTLHtmlDir $output
    log info "移动${JTLHtmlDir}目录到临时归档目录: ${output}"
else
    log warn "${JTLHtmlDir}目录不存在"
fi

if [ -f $JTLFile ]; then
    if [ $hasHtmlDir ]; then
        tar -czvf $JTLZipFile $JTLFile && mv $JTLZipFile $output && rm $JTLFile
        log info "压缩${JTLFile}文件为${JTLZipFile}，删除${JTLFile}文件，移动${JTLZipFile}文件到临时归档目录: ${output}"
    else
        tar -czvf $JTLZipFile $JTLFile && mv $JTLZipFile $output && mv $JTLFile $output
        log info "压缩${JTLFile}文件为${JTLZipFile}，移动${JTLFile}和${JTLZipFile}文件到临时归档目录: ${output}"
    fi
else 
    log warn "${JTLFile}文件不存在"
fi

log info "临时归档结束!!!"
mv $logfile $output
