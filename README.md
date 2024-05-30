使用run.sh脚本，减少使用JMeter CLI MOD压测时的一些重复性操作，让我们更关注结果本身。

简单的测试流程如下：
1. 删除/归档上次压测时产生的文件，包括JMeter和nmon监控数据，分布在压力机上和被监控服务器上。
2. 发起JMeter压测，发起nmon监控。
3. 下载nmon的监控文件，分析监控文件。
4. 归档测试数据，包括JMeter产生的数据，nmon监控数据。


按上述测试流程的顺序，使用的命令如下：
```shell
# step 1
# 删除JMeter产生的数据：res目录， res.jtl文件，jmeter.log日志
# 删除下载到压力机nmon目录下的nmon文件
rm -rf res* nmon/*nmon* jmeter.log 
# 删除被监控服务器上监控文件
# rssh是以前自己写的小程序，可利用ssh2在各远程服务器上批量执行命令以及上传下载单个文件。
# 其中all代表server.json配置文件中有效的服务器信息。
# rssh > [str] 表达运行rssh命令连接服务器后，再输入[str]批量执行命令。
rssh > all rm perf/res.nmon 

# step 2
# 使用JMeter CLI MOD，发起JMeter压测
jmeter -Jjmeter.reportgenerator.overall_granularity=2000 -Jsummariser.interval=10 -JThreads=100 -JRampup=1 -JDuration=310 -JLoopOrRampupCount=-1 -n -t 1.jmx -l res.jtl -e -o res
# 发起nmon监控
rssh > all exec nmon -F perf/res.nmon -t -s 1 -c 300
# 查看jmeter命令返显的概述结果（每10秒的增量，从测试开始到现在平均值，包括TPS, 平均响应时间，错误数据和错误率）

# step 3
# 下载nmon文件
rssh > all get perf/res.nmon ./
# 快速分析nmon文件并查看文件(cpu) , rnmon为自己写的小程序，可快速分析当前目录下.nmon文件的cpu%使用，包括usr%,sys%, idle%...和各项值的标准差（用于查看曲线波动情况） 
# 若要详细查看nmon文件，使用nmon官方提供的Nmon-Analyser工具生成excel图表查看
rnmon ./ > res.nmon.txt && cat res.nmon.txt

# step 4
# 新建本地目录并按场景和一些规范重命令
# 使用sftp工具，下载压力机上收集的数据到本地目录，包括res目录，res.jtl, jmeter.log和nmon目录
# 打开res/index.html查看JMeter生成的压测图表，分析当前测试结果。
```
或者利用免密登录形式，使用ssh、scp命令完成上述过程：
```shell
# step 1
# 删除JMeter产生的数据：res目录， res.jtl文件，jmeter.log日志
rm -rf res* nmon/*nmon* jmeter.log 
# 删除被监控服务器上监控文件
ssh user@ip rm perf/res.nmon 
...

# step 2
jmeter -Jjmeter.reportgenerator.overall_granularity=2000 -Jsummariser.interval=10 -JThreads=100 -JRampup=1 -JDuration=310 -JLoopOrRampupCount=-1 -n -t 1.jmx -l res.jtl -e -o res
# 发起nmon监控
ssh user@ip nmon -F perf/res.nmon -t -s 1 -c 300
...
# 查看jmeter命令返显的概述结果（每10秒的增量，从测试开始到现在平均值，包括TPS, 平均响应时间，错误数据和错误率）

# step 3
# 下载nmon文件
scp user@ip:per/res.nmon ./
...
# 快速分析nmon文件并查看文件(cpu) , rnmon为自己写的小程序，可快速分析当前目录下.nmon文件的cpu%使用，包括usr%,sys%, idle%...和各项值的标准差（用于查看曲线波动情况） 
rnmon ./ > res.nmon.txt && cat res.nmon.txt

# step 4
# 新建本地目录并按场景和一些规范重命令
# 使用sftp工具，下载压力机上收集的数据到本地目录，包括res目录，res.jtl, jmeter.log和nmon目录
# 打开res/index.html查看JMeter生成的压测图表，分析当前测试结果。
```
每次测试执行上述基本固定的操作，感觉还是挻繁琐的OVO

故想利用run.sh脚本完成以下目标: 

1. 运行前检查，删除/归档上次压测时产生的数据。
2. 简化运行时的参数输入（减少jmeter命令附带参数的长度）
3. 自动计算nmon监控的时长并发监控。
4. 下载并分析nmon文件到压力机。
5. 按一定的规则，归档数据。


因不同的项目可能使用不同的参数测试，且单次项目中这些参数是基本不变的，故使用test.proerties配置文件存放相关的JMeter参数和自定义的参数，比如:
```proerties
# 发压地址
ip=192.168.8.8
# 更改jmeter命令测试时返显结果的刷新频率
summariser.interval=10
# 更改jmeter命令生成图表曲线相领两点间的间隔时间
jmeter.reportgenerator.overall_granularity=2000
```

使用run.sh脚本的好处，是让我们把时间集中在测试结果的表现，而不是在工作中穿插大量、小、繁琐且无意义的事件。

备注： 把run.sh脚本放入$PATH里(source env.sh)，且在同级目录下放入预定的test.proerties文件，这样可省略不同项目在同台压力机上，在不同目录之间复制run.sh脚本和test.proerties文件的烦恼。

