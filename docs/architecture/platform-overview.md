# Enterprise Ansible Platform总体架构

## 架构目标

该平台通过master01统一管理六台Enterprise Linux节点，实现基础环境、Web服务、数据库、Kubernetes、监控日志和备份恢复的集中自动化。

## 节点拓扑

```mermaid
flowchart TB
    ADMIN["运维管理员"] --> MASTER

    subgraph CONTROL["自动化控制层"]
        MASTER["master01<br/>Ansible Control Node<br/>192.168.11.10"]
    end

    subgraph SERVICE["业务服务层"]
        NODE01["node01<br/>Nginx Web<br/>192.168.11.11"]
        NODE02["node02<br/>MariaDB<br/>192.168.11.12"]
    end

    subgraph KUBERNETES["Kubernetes集群"]
        NODE03["node03<br/>Control Plane + etcd<br/>192.168.11.13"]
        NODE04["node04<br/>Worker<br/>192.168.11.14"]
        NODE03 <-->|"Kubernetes API与集群通信"| NODE04
    end

    subgraph OBSERVABILITY["可观测性平台"]
        NODE05["node05<br/>Prometheus + Grafana + Loki<br/>192.168.11.15"]
    end

    subgraph PROTECTION["数据保护层"]
        NODE06["node06<br/>Unified Backup Server<br/>192.168.11.16"]
    end

    MASTER -->|"Ansible + SSH"| NODE01
    MASTER -->|"Ansible + SSH"| NODE02
    MASTER -->|"Ansible + SSH"| NODE03
    MASTER -->|"Ansible + SSH"| NODE04
    MASTER -->|"Ansible + SSH"| NODE05
    MASTER -->|"Ansible + SSH"| NODE06

    NODE01 -.->|"业务数据库访问"| NODE02
    NODE03 -.->|"应用数据库访问"| NODE02
    NODE04 -.->|"应用数据库访问"| NODE02

    NODE05 -.->|"Prometheus主动抓取指标"| NODE01
    NODE05 -.->|"Prometheus主动抓取指标"| NODE02
    NODE05 -.->|"Prometheus主动抓取指标"| NODE03
    NODE05 -.->|"Prometheus主动抓取指标"| NODE04
    NODE05 -.->|"本机指标与日志"| NODE05
    NODE05 -.->|"Prometheus主动抓取指标"| NODE06

    NODE01 -->|"Nginx备份"| NODE06
    NODE02 -->|"MariaDB备份"| NODE06
    NODE03 -->|"etcd与Control Plane备份"| NODE06
    NODE04 -->|"Worker配置备份"| NODE06
    NODE05 -->|"监控日志平台备份"| NODE06
```

## 架构分层

| 层级 | 组件 | 作用 |
|---|---|---|
| 自动化控制层 | master01、Ansible | Inventory管理、Role编排、批量部署和验证 |
| 业务服务层 | Nginx、MariaDB | 提供Web服务和数据存储 |
| 容器平台层 | Kubernetes、containerd、Calico、etcd | 提供容器编排和集群状态存储 |
| 可观测性层 | Prometheus、Grafana、Loki、Promtail | 指标采集、日志聚合和可视化 |
| 数据保护层 | node06、备份客户端、SHA256 | 统一接收、校验、保留和清理备份 |

## 管理边界

- master01只负责自动化控制，不承载业务服务。
- node03和node04组成Kubernetes集群。
- node05集中承载监控和日志平台。
- node06与业务节点分离，集中保存备份。
- 敏感变量通过Ansible Vault管理。
- 大型安装文件通过Git LFS管理。
