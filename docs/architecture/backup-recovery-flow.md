# 统一备份与隔离恢复流程

## 备份对象

| 节点 | 备份内容 |
|---|---|
| node01 | Nginx配置和站点文件 |
| node02 | MariaDB数据库逻辑备份 |
| node03 | etcd快照、Control Plane配置和集群元数据 |
| node04 | Kubernetes Worker配置 |
| node05 | Prometheus、Grafana、Loki配置与数据 |
| node06 | 统一保存所有节点的远端备份 |

## 备份数据流

```mermaid
flowchart LR
    subgraph SOURCES["备份源节点"]
        N1["node01<br/>Nginx"]
        N2["node02<br/>MariaDB"]
        N3["node03<br/>etcd + Control Plane"]
        N4["node04<br/>Worker配置"]
        N5["node05<br/>Prometheus + Grafana + Loki"]
    end

    subgraph CLIENT_PROCESS["客户端备份流程"]
        CRON["Cron定时任务"]
        SCRIPT["备份脚本"]
        STAGING["本地临时目录"]
        LOCALHASH["本地SHA256"]
        TRANSFER["SSH + rsync/scp传输"]
    end

    subgraph SERVER["node06统一备份服务器"]
        STORAGE["/backup/data"]
        REMOTEHASH["远端SHA256验证"]
        STATUS["备份状态汇总"]
        CAPACITY["容量保护"]
        RETENTION["保留策略与过期清理"]
    end

    N1 --> SCRIPT
    N2 --> SCRIPT
    N3 --> SCRIPT
    N4 --> SCRIPT
    N5 --> SCRIPT

    CRON --> SCRIPT
    SCRIPT --> STAGING
    STAGING --> LOCALHASH
    LOCALHASH --> TRANSFER
    TRANSFER --> STORAGE
    STORAGE --> REMOTEHASH
    REMOTEHASH --> STATUS
    STATUS --> CAPACITY
    CAPACITY --> RETENTION
```

## 单次备份执行过程

```text
Cron触发
  ↓
检查依赖、服务和源文件
  ↓
生成备份文件或快照
  ↓
生成本地SHA256
  ↓
通过专用SSH密钥传输到node06
  ↓
node06生成或验证远端SHA256
  ↓
写入备份日志和状态汇总
  ↓
执行容量保护与保留策略
```

## 隔离恢复流程

```mermaid
flowchart TB
    BACKUP["node06已验证备份"] --> SELECT["选择恢复点"]
    SELECT --> HASH["验证SHA256"]
    HASH --> COPY["复制到恢复演练目录"]

    COPY --> R1["node01<br/>Nginx配置验证"]
    COPY --> R2["node02<br/>MariaDB临时实例"]
    COPY --> R3["node03<br/>etcd与Control Plane验证"]
    COPY --> R4["node04<br/>Worker配置验证"]
    COPY --> R5["node05<br/>Prometheus、Grafana、Loki验证"]

    R1 --> REPORT["生成恢复演练报告"]
    R2 --> REPORT
    R3 --> REPORT
    R4 --> REPORT
    R5 --> REPORT

    REPORT --> HEALTH["检查原生产服务健康"]
    HEALTH --> RESULT{"所有验证通过？"}
    RESULT -->|"是"| PASS["恢复演练PASS"]
    RESULT -->|"否"| FAIL["保留现场并分析失败原因"]
```

## 隔离原则

- 不直接覆盖生产配置。
- 不直接恢复到生产数据目录。
- MariaDB使用独立临时实例和独立Socket。
- etcd优先进行快照状态和恢复目录验证。
- Prometheus使用TSDB分析工具验证数据块。
- Grafana验证数据库文件及配置。
- Loki根据当前版本支持的校验方式验证配置和数据目录。
- 演练结束后确认原服务仍然正常运行。

## 数据完整性保护

备份同时保留：

```text
备份文件
SHA256校验文件
执行日志
远端校验结果
恢复演练报告
```

只有备份生成、传输、校验和恢复验证全部通过，才能认为备份链路有效。

## node06维护职责

```text
统一目录规范
    ↓
备份状态扫描
    ↓
容量阈值检查
    ↓
保留周期判断
    ↓
过期文件清理
    ↓
输出汇总报告
```

node06只负责集中保存和维护备份，不直接承载node01～node05的生产服务。
