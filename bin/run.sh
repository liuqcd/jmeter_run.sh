#!/bin/sh

scriptdir=`dirname $0` 
curdir=$PWD

logfile="run.log"

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

# 不带参数运行run.sh时显示帮助文档
if [ $# -eq 0 ]; then
    cat ${scriptdir}/run_help.txt
    exit 1
fi

# 清空本脚本的日志文件
echo '' > $logfile

# 取得run.sh脚本参数
## "-选项 value"存放在map中。
## "=选项=value"存放在Prop中
declare -A shellMap1
declare -A shellMap2
declare -A shellProp
while [ $# -ne 0 ]
do
    case "$1" in
        "-jmx" ) shift && shellMap1["JmxFile"]=$1 ;;
        "-j" ) shift && shellMap1["JmxFile"]=$1 ;;

        "-prop" ) shift && shellMap1["PropFile"]=$1 ;;
        "-p" ) shift && shellMap1["PropFile"]=$1 ;;

        "-pnew" ) shellMap1["Pnew"]=true ;;

        "-threads" ) shift && shellMap1["Threads"]=$1 ;;
        "-thd" ) shift && shellMap1["Threads"]=$1 ;;
        "-t" ) shift && shellMap1["Threads"]=$1 ;;

        "-rampup" ) shift && shellMap1["Rampup"]=$1 ;;
        "-r" ) shift && shellMap1["Rampup"]=$1 ;;

        "-duration" ) shift && shellMap1["Duration"]=$1 ;;
        "-d" ) shift && shellMap1["Duration"]=$1 ;;

        "-count" ) shift && shellMap1["LoopOrRampupCount"]=$1 ;;
        "-c" ) shift && shellMap1["LoopOrRampupCount"]=$1 ;;

        "-nmon" ) 
            shellMap1["nmonswitch"]=true
            if [[ $# -ge 2 ]]; then 
                # run.sh脚本剩余参数的个数大于等于2
                if [[ "$2" =~ -.* ]]; then 
                    # "-nmon"选项后跟着以"-"打头的选项，说明"-nmon"选项未指定[regex]，脚本后面会赋予默认值
                    echo "111"
                    shellMap1["nmon"]=""
                else 
                    echo "222"
                    shift && shellMap1["nmon"]=$1
                fi
            else 
                if [[ $# -le 1 ]]; then 
                    echo "333"
                    # 小于等于1，脚本后面赋予默认值
                    shellMap1["nmon"]=""
                else 
                    echo "444"
                    shift && shellMap1["nmon"]=$1
                fi
            fi ;;

        "-nmondir" ) shift && shellMap1["nmondir"]=$1 ;;

        "-nmonident" ) shift && shellMap1["nmonident"]=$1 ;;

        * ) 
            # -E 选项用于向jmeter程序传入与上述选项名相同的参数，并放入map中
            # 例如： "-E-d value"转换为"-d value"传入jmeter中。
            # 例如： "-E-Jsummariser.interval=10 "转换为"-Jsummariser.interval=10"传入jmeter中
            if [[ "$1" =~ .*=.* ]]; then 
                if [[ "$1" =~ -[eE].* ]]; then
                    name=`echo $1 | cut -d'=' -f1 | cut -c3-`
                else 
                    name=`echo $1 | cut -d'=' -f1`
                fi
                value=`echo $1 | cut -d'=' -f2`
                shellProp["$name"]=$value
            else
                if [[ "$1" =~ -[eE].* ]]; then
                    name=`echo $1 | cut -d'=' -f1 | cut -c3-`
                else
                    name=$1
                fi
                if [[ $# -ge 2 ]]; then 
                    # run.sh脚本剩余参数的个数大于等于2
                    if [[ "$2" =~ -.* ]]; then 
                        value=""
                    else
                        shift && value=$1
                    fi
                else
                    value=""

                fi
                shellMap2["$name"]=$value
            fi
            ;;
    esac
    if [[ $# -ne 0 ]]; then
        shift
    fi
done

# 调试代码
# log debug "shellMap1:"
# for key in ${!shellMap1[*]};do
#   log debug "${key}: ${shellMap1[$key]}"
# done
# echo ""
# log debug "shellMap2:"
# for key in ${!shellMap2[*]};do
#   log debug ${key}: ${shellMap2[$key]}
# done
# echo ""
# log debug "shellProp:"
# for key in ${!shellProp[*]};do
#   log debug ${key}: ${shellProp[$key]}
# done
# echo ""

# 参数赋值和校验
## PropNew
PropNew=${shellMap1["Pnew"]}
if [[ -n $PropNew ]]; then
    PropNew=true
fi
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
## JmxFile
JmxFile=${shellMap1["JmxFile"]}
if [[ -z $JmxFile ]]; then
    log error "缺少必要的参数: -jmx <JmxFile> or -j <JmxFile>"
    exit 1
fi
## jmx线程组相关参数
### 
Threads=${shellMap1["Threads"]}
if [[ -z $Threads ]]; then
    log error "缺少必要的参数: -threads <num> or -thd <num> or -t <num>"
    exit 1
fi
### 
Rampup=${shellMap1["Rampup"]}
if [[ -z $Rampup ]]; then
    Rampup=1
    log warn "未指定参数: -rampup <num> or -r <num> ， 使用默认值: 1"
fi
### 
Duration=${shellMap1["Duration"]}
if [[ -z $Duration ]]; then
    log error "缺少必要的参数: -duration <num> or -d <num>"
    exit 1
fi
### 
LoopOrRampupCount=${shellMap1["LoopOrRampupCount"]}
if [[ -z $LoopOrRampupCount ]]; then
    log error "缺少必要的参数: -count <num> or -c <num>"
    exit 1
fi
##  PropFile
PropFile=${shellMap1["PropFile"]}
if [[ -n $PropFile ]]; then
    log info "指定properties配置文件: $PropFile"
else
    PropFile="test.properties"
    log warn "未指定proerties配置文件，使用默认值: $PropFile"
fi
## ScriptARGS参数汇总（排除指定/创建properties文件相关的参数）
ScriptARGS="-JThreads=${Threads} -JRampup=${Rampup} -JDuration=${Duration} -JLoopOrRampupCount=${LoopOrRampupCount}"
log info "ScriptARGS参数: $ScriptARGS"
## nmon
### nmonswitch
nmonswitch=${shellMap1["nmonswitch"]}
### nmon
nmonregex=${shellMap1["nmon"]}
if [[ -z $nmonregex && -n $nmonswitch ]]; then
    nmonregex="all"
    log warn "-nmon [regex] 未指定[regex]值，使用默认值: all"
fi

### nmondir
nmondir=${shellMap1["nmondir"]}
if [[ -n $nmonswitch ]]; then
    if [[ -n $nmondir ]]; then
        if [[ "$nmondir" == *"/" ]]; then
            nmonprogm="${nmondir}nmon"
        elif [[ "$nmondir" == *"/nmon" ]]; then
            nmonprogm="${nmondir}"
        else
            nmonprogm="${nmondir}/nmon"
        fi
    else
        nmonprogm="nmon"
    fi
fi

### nmonident
nmonident=${shellMap1["nmonident"]}
if [[ -z $nmonident && -n $nmonswitch ]]; then
    nmonident="perf"
    log warn "-nmonident [str] 未指定[str]值，使用默认值: perf"
fi
### NmonARGS参数汇总
if [ $nmonswitch ]; then 
    if [[ -n $nmondir ]]; then 
        NmonARGS="-nmon ${nmon} -nmondir ${nmondir} -nmonident ${nmonident}"
    else
        NmonARGS="-nmon ${nmon} -nmonident ${nmonident}"
    fi
    log info "本次传入处理nmon相关的参数有: $NmonARGS"
fi

# 读取properties文件，去除注释行
##  把配置信息转为以"-Jname=value "形式的字符串，传递到jmeter
declare -A propMap
if [ ! -f $PropFile ]; then
    log error "${PropFile}配置文件不存在"
    exit 1
fi
for prop in `grep -v "#" < $PropFile | grep -v "grep"`
do
    var=(`echo $prop | cut -d'=' -f1,2  --output-delimiter=' '`)
    propMap[${var[0]}]=${var[1]}
done
# 调试代码
# echo ""
# log debug "propMap:"
# for key in ${!propMap[*]};do
#   log debug "${key}: ${propMap[$key]}"
# done
# echo ""

# 动态计算
## 计算远程服务器需监视的时长
monitor_duration=`expr $Rampup + $Duration`
monitor_duration=`expr $monitor_duration + 3`
log info "动态计算，增加3秒jmeter启动时间后，monitor_duration: $monitor_duration "
## 计算远程服务器上运行nmon监视的间隔时间和监视次数
monitor_interval=`expr $monitor_duration / 1440`
monitor_interval=`expr $monitor_interval + 1`
log info "动态计算，monitor_interval: $monitor_interval"
monitor_count=`expr $monitor_duration / $monitor_interval`
log info "动态计算，monitor_count: $monitor_count"

## 计算jmeter运行结束后，生成hmtl报告图表上相邻两点间的间隔时长
## 涉及jmeter的jmeter.reportgenerator.overall_granularity参数
## 当properties文件中存在该参数时，脚本以文件中的设置为准。
if [ $monitor_duration -lt 240 ]; then # <4min, 最大240个点
    overall_granularity=1
elif [ $monitor_duration -lt 1860 ]; then # <31min, 最大930个点
    overall_granularity=2
elif [ $monitor_duration -le 9000 ]; then  # <2.5h, 最大900个点
    overall_granularity=10
elif [ $monitor_duration -le 19800 ]; then # <5.5h，最大990个点
    overall_granularity=20
else
    overall_granularity=30  # 12.5h，有1500个点
fi
log info "动态计算，overall_granularity: $overall_granularity"
name="jmeter.reportgenerator.overall_granularity"
value=${propMap["$name"]}
if [[ -z $value ]]; then
    propMap[$name]=$overall_granularity
    log info "${PropFile}文件中，未设置${name}选项，使用动态计算值: ${overall_granularity}"
fi

# 参数汇总
## run.sh传入的参数若与properties文件中相同，则覆盖。
PropARGS=""
for key in ${!propMap[*]};do
    name=$key
    value=${propMap[$name]}
    # 变量是否在 shellProp 中存在，若存在则以 shellProp 里有为准
    # 意味着run.sh脚本传入的参数，优于properties文件的设置
    shellValue=${shellProp["-J$name"]}
    if [[ -n $shellValue ]]; then
        propMap[$name]=$shellValue
        value=$shellValue
        log warn "${PropFile}文件中${name}选项，被ShellARGS参数: -E-J${name}=${value} 覆盖"
    fi
    PropARGS="${PropARGS} -J${name}=${value}"
done
log info "properties文件配置的参数：$PropARGS"

# 运行前操作
## 运行前初始化变量
JTLFile="res.jtl"
JTLZipFile="${JTLFile}.tar.gz"
JTLHtmlDir="res"
JMeterLog="jmeter.log"
## 拼接最终传给jmeter的参数ARGS
ARGS="$PropARGS $ScriptARGS $OtherARGS -n -t $JmxFile -l $JTLFile -e -o $JTLHtmlDir"
log info "jmeter命令运行的参数： $ARGS"

## 运行前删除老的测试数据
log info "运行前检查..."
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

## 远程服务器执行监视的初始化
### 在远程服务器上查找指定标识的nmon，并kill掉。
### 若没有标识符nmonident，则Kill掉所有正在运行的nmon程序
### grep -v jmx 用于排除本脚本运行的进程
if [ $nmonswitch ]; then 
    if [[ -n $nmonident ]]; then
        rssh_args="-l $logfile $nmonregex exec ps -- -ef | grep $nmonident | grep nmon |grep -v jmx | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
    else
        rssh_args="-l $logfile $nmonregex exec ps -- -ef | grep nmon |grep -v jmx | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
    fi
    log info "杀掉远程服务器上可能正在运行的nmon程序..., 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "杀掉远程服务器上可能正在运行的nmon程序结束!!!"
fi

## 运行前设置临时目录，格式: 月日-时分
### 临时目录变量
output=`date "+%m%d-%H%M"`
### 删除已存在的临时目录
if [ -d $output ]; then
    log warn "删除已存在${output}目录, 一分钟内发起两次测试, 大概率前一次测试为无效，故默认清除上一次的结果"
    rm -rf $output
fi
### 本地新建临时目录
mkdir ${output}
log info "新建本地归档目录: ${output}, 其格式为: 月日-时分"

### 远程服务器上，新建临时目录
if [ $nmonswitch ]; then 
    local_nmon_archive_dir="${output}/nmon"
    mkdir -p $local_nmon_archive_dir
    log info "新建本地nmon文件的存放目录: ${local_nmon_archive_dir}"

    if [[ -n $nmonident ]]; then
        remote_nmon_archive_dir="${nmonident}/${output}"
    else
        remote_nmon_archive_dir=${output}
    fi

    rssh_args="-l $logfile $nmonregex exec mkdir -- -p $remote_nmon_archive_dir"
    log info "远程服务器上, 新建临时目录: ${remote_nmon_archive_dir}, 执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
fi

log info "运行前检查结束!!!"

###################################################################################
# 发起nmon监视
if [ $nmonswitch ]; then 
    monitor_nmon_file="${remote_nmon_archive_dir}/res.nmon"
    rssh_args="-l $logfile $nmonregex exec $nmonprogm -- -F $monitor_nmon_file -t -s $monitor_interval -c $monitor_count"
    log info "nmon监控发起开始..., 执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "nmon监控发起结束!!!"
    echo ""
fi

# 以CLI mode运行jmeter
log info "运行jmeter..."
jmeter $ARGS 
retcode=$?
log info "运行jmeter结束!!!，返回码: $retcode"
###################################################################################

# 运行后操作
## 下载远程服务器上监视系统资源的nmon文件
if [ $nmonswitch ]; then 
    rssh_args="-l $logfile $nmonregex get $monitor_nmon_file $local_nmon_archive_dir"
    log info "下载远程服务器上的nmon文件..., 将执行命令: rssh_async ${rssh_args}"
    rssh_async $rssh_args
    log info "下载远程服务器上的nmon文件结束!!!"
fi

## 下载nmon文件成功后，使用rnmon快速分析结果，并删除服务器的临时目录
if [ $nmonswitch ]; then 
    res=`ls ${local_nmon_archive_dir}/*res.nmon 2>/dev/null`
    if [ -n "$res" ]; then
        # 快速分析nmon文件
        res_nmon_file="${local_nmon_archive_dir}/res.nmon.txt"
        rnmon ${local_nmon_archive_dir} > ${res_nmon_file}
        log info "使用rnmon程序，分析${local_nmon_archive_dir}目录下的nmon文件，其结果为:"
        cat ${res_nmon_file}
        # 删除服务器的临时目录
        rssh_args="-l $logfile $nmonregex exec rm -- -rf ${remote_nmon_archive_dir}"
        log info "监测${local_nmon_archive_dir}目录中存在*res.nmon文件，删除远程服务器上临时目录..., 执行命令: rssh_async ${rssh_args}"
        rssh_async $rssh_args
        log info "删除远程服务器上的临时目录结束!!!"
    else
        log error "监测${local_nmon_archive_dir}目录中不存在*res.nmon文件，代表下载nmon文件失败，请检查后重新手工下载监控文件: ${monitor_nmon_file}, 本地的nmon临时目录里有: ${res}"
    fi
fi

## 归档工作目录下的数据到临时目录中
log info "临时归档..."
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
        ### jmeter正常结束，则删除JTL文件，保留其压缩文件
        tar -czvf $JTLZipFile $JTLFile && mv $JTLZipFile $output && rm $JTLFile
        log info "压缩${JTLFile}文件为${JTLZipFile}，删除${JTLFile}文件，移动${JTLZipFile}文件到临时归档目录: ${output}"
    else
        ### jmeter非正常结束，保留JTL文件，不执行压缩操作，方便测试人员查看JTL文件，重新手动生成html报告
        tar -czvf $JTLZipFile $JTLFile && mv $JTLZipFile $output && mv $JTLFile $output
        log info "压缩${JTLFile}文件为${JTLZipFile}，移动${JTLFile}和${JTLZipFile}文件到临时归档目录: ${output}"
    fi
else 
    log warn "${JTLFile}文件不存在"
fi
log info "临时归档结束!!!"

## 移动run.sh脚本的日志文件到临时目录
mv $logfile $output
