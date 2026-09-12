# Enterprise Ansible Platform

一个面向企业级 Linux 基础设施的 Ansible 自动化项目，覆盖基础环境标准化、Web服务、数据库、Kubernetes、监控日志、统一备份、隔离恢复和安全验收。

当前正式版本：`v1.0.0`

## 项目简介

本项目使用 Ansible 对六台 Enterprise Linux 节点进行统一管理，实现从基础环境初始化到业务服务部署、监控日志接入、数据备份、恢复演练和最终验收的完整自动化流程。

项目重点解决以下问题：

- 多节点基础环境配置不一致
- 服务部署依赖人工操作
- Kubernetes节点配置难以标准化
- 监控、日志和备份体系相互独立
- 备份成功但恢复能力未经验证
- 配置文件中可能存在明文凭据
- Playbook重复执行可能产生非预期变更
- 项目缺少可审计的部署和验收证据

## 项目架构

```text
                         master01
                    Ansible Control Node
                              |
          +-------------------+-------------------+
          |                   |                   |
       node01              node02              node03
       Nginx               MariaDB             Kubernetes
       Web                 Database            Control Plane
                                                   |
                                                node04
                                                Kubernetes
                                                Worker

       node05                                      node06
       Prometheus                                  Backup Server
       Grafana                                     Retention
       Loki                                        Capacity Guard
                                                   Status Report
                                                   Restore Evidence

node01～node06
    |
    +-- Node Exporter --> Prometheus
    |
    +-- Promtail -------> Loki -------> Grafana
    |
    +-- Backup Client --> node06
```

## 节点规划

| 节点 | 实验地址 | 主要角色 |
|---|---|---|
| master01 | `192.168.11.10` | Ansible控制节点 |
| node01 | `192.168.11.11` | Nginx Web服务 |
| node02 | `192.168.11.12` | MariaDB数据库 |
| node03 | `192.168.11.13` | Kubernetes Control Plane、etcd |
| node04 | `192.168.11.14` | Kubernetes Worker |
| node05 | `192.168.11.15` | Prometheus、Grafana、Loki |
| node06 | `192.168.11.16` | 统一备份服务器 |

> 以上地址仅用于隔离实验环境，部署到其他环境时应通过Inventory变量调整。

## 技术栈

| 分类 | 技术 |
|---|---|
| 自动化 | Ansible Core 2.16 |
| 操作系统 | Enterprise Linux系列 |
| Web服务 | Nginx |
| 数据库 | MariaDB |
| 容器运行时 | containerd |
| 容器编排 | Kubernetes |
| 网络组件 | Calico |
| 指标监控 | Prometheus、Node Exporter |
| 可视化 | Grafana |
| 日志平台 | Loki、Promtail |
| 数据保护 | etcd snapshot、SQL dump、tar、rsync、SHA256 |
| 凭据保护 | Ansible Vault、`no_log` |
| 大文件管理 | Git LFS |
| 版本管理 | Git、GitHub Releases |

## 仓库结构

```text
.
├── ansible.cfg
├── collections/
│   └── requirements.yml
├── docs/
│   └── releases/
├── files/
├── inventory/
│   ├── group_vars/
│   ├── host_vars/
│   └── hosts.yml
├── playbooks/
├── roles/
├── .gitattributes
├── .gitignore
├── .yamllint
└── README.md
```

### 主要目录

- `inventory/`：主机清单、组变量和节点变量
- `playbooks/`：各服务及平台的部署入口
- `roles/`：可复用的Ansible Role
- `collections/`：Ansible Collection依赖声明
- `docs/`：项目文档和版本说明
- `files/`：需要分发到目标节点的受控文件

运行时生成的报告、验收归档、临时文件和私钥不会提交到Git仓库。

## 已实现功能

### 基础环境

- Linux基础软件安装
- 时间同步和主机名配置
- SSH管理密钥部署
- 用户及权限管理
- SELinux运行状态检查
- 防火墙与系统参数配置
- Node Exporter统一部署

### Web与数据库

- Nginx自动安装和配置
- Nginx配置语法验证
- MariaDB自动安装和初始化
- 数据库及业务用户创建
- 数据库账号权限管理
- 敏感数据库任务日志保护

### Kubernetes

- Control Plane和Worker节点准备
- containerd配置
- Kubernetes软件仓库配置
- kubeadm初始化与节点加入
- Calico网络部署
- Kubernetes API、节点和Pod健康验证
- etcd运行状态和快照验证

### 监控与日志

- Prometheus部署及TSDB管理
- Node Exporter指标采集
- Grafana部署及数据源配置
- Loki日志存储
- Promtail多节点日志采集
- Prometheus、Grafana和Loki健康检查
- Promtail到Loki链路验证

### 备份与恢复

- node01 Nginx配置和站点备份
- node02 MariaDB逻辑备份
- node03 etcd及Kubernetes Control Plane备份
- node04 Kubernetes Worker配置备份
- node05 Prometheus、Grafana和Loki备份
- node06统一备份保留策略
- 容量保护和过期清理
- 备份状态汇总
- 本地和远端SHA256校验
- 定时任务与日志轮转
- node01～node05隔离恢复演练

## Inventory分组

```text
all
├── allservers
│   ├── node01
│   ├── node02
│   ├── node03
│   ├── node04
│   ├── node05
│   └── node06
├── web
│   └── node01
├── database
│   └── node02
├── k8s
│   ├── node03
│   └── node04
├── k8s_master
│   └── node03
├── k8s_worker
│   └── node04
├── monitoring
│   └── node05
├── backup
│   └── node06
└── log_clients
    ├── node01
    ├── node02
    ├── node03
    ├── node04
    ├── node05
    └── node06
```

## 获取项目

仓库使用Git LFS管理Prometheus、Loki、Promtail和Node Exporter等大型文件。

```bash
git lfs install

git clone \
  ssh://git@ssh.github.com:443/fu-Del/enterprise-ansible-platform.git

cd enterprise-ansible-platform

git lfs pull
```

检出正式版本：

```bash
git checkout v1.0.0
git lfs pull
```

检出标签后出现 `detached HEAD` 属于正常现象。

## 环境准备

安装Ansible依赖：

```bash
ansible-galaxy collection install \
  -r collections/requirements.yml
```

检查版本：

```bash
ansible --version
ansible-galaxy collection list
git lfs version
```

## 配置Inventory

根据实际环境修改：

```text
inventory/hosts.yml
inventory/group_vars/
inventory/host_vars/
```

检查Inventory：

```bash
ansible-inventory \
  --graph \
  --ask-vault-pass
```

检查所有节点连通性：

```bash
ansible allservers \
  -m ansible.builtin.ping \
  --ask-vault-pass
```

## 部署入口

主要Playbook位于 `playbooks/`。

基础环境示例：

```bash
ansible-playbook \
  playbooks/common.yml \
  --ask-vault-pass
```

Nginx部署：

```bash
ansible-playbook \
  playbooks/nginx.yml \
  --ask-vault-pass
```

MariaDB部署：

```bash
ansible-playbook \
  playbooks/mysql.yml \
  --ask-vault-pass
```

Kubernetes部署：

```bash
ansible-playbook \
  playbooks/kubernetes.yml \
  --ask-vault-pass
```

监控平台部署：

```bash
ansible-playbook \
  playbooks/monitoring.yml \
  --ask-vault-pass
```

日志平台部署：

```bash
ansible-playbook \
  playbooks/logging.yml \
  --ask-vault-pass
```

> 执行前应根据目标环境检查Inventory、变量、Vault内容和Playbook适用范围。

## 备份入口

Nginx备份：

```bash
ansible-playbook \
  playbooks/backup-nginx.yml \
  --ask-vault-pass
```

MariaDB备份：

```bash
ansible-playbook \
  playbooks/backup-mariadb.yml \
  --ask-vault-pass
```

Kubernetes Control Plane和etcd备份：

```bash
ansible-playbook \
  playbooks/backup-k8s-controlplane.yml \
  --ask-vault-pass
```

Kubernetes Worker备份：

```bash
ansible-playbook \
  playbooks/backup-k8s-worker.yml \
  --ask-vault-pass
```

监控日志平台备份：

```bash
ansible-playbook \
  playbooks/backup-monitoring-platform.yml \
  --ask-vault-pass
```

## 静态检查

YAML检查：

```bash
yamllint -c .yamllint \
  inventory \
  playbooks \
  roles
```

Playbook语法检查示例：

```bash
ansible-playbook \
  playbooks/common.yml \
  --syntax-check \
  --ask-vault-pass
```

Inventory检查：

```bash
ansible-inventory \
  --list \
  --ask-vault-pass
```

## 幂等性验证

每个核心Playbook按照以下流程验证：

```text
check mode
    ↓
第一次真实执行
    ↓
第二次真实执行
    ↓
确认第二次 changed=0
    ↓
服务运行健康验证
```

项目最终验证结果：

| 验证项目 | 结果 |
|---|---|
| YAML静态检查 | PASS |
| Inventory解析 | PASS |
| Playbook语法检查 | PASS |
| 基础环境幂等性 | PASS |
| Nginx与MariaDB | PASS |
| 监控日志平台 | PASS |
| Kubernetes全链路 | PASS |
| 备份Playbook | 7/7 PASS |
| 第二次执行变更数 | 0 |
| 失败主机 | 0 |
| 不可达主机 | 0 |

## 安全设计

- 敏感变量使用Ansible Vault加密
- Vault文件权限设置为`0600`
- Vault密码文件不提交到Git
- SSH私钥不提交到Git
- 数据库密码不以明文形式保存
- 敏感任务使用`no_log: true`
- Git历史已执行明文凭据审计
- 临时Inventory导出文件在使用后清理
- 运行报告和验收归档通过`.gitignore`排除

当前Vault文件：

```text
inventory/group_vars/database/vault.yml
inventory/group_vars/monitoring/vault.yml
```

使用前需要准备正确的Vault密码。

## 备份恢复验证

项目不仅验证备份文件是否生成，还进行了隔离恢复演练：

| 节点 | 恢复对象 | 结果 |
|---|---|---|
| node01 | Nginx配置与站点 | PASS |
| node02 | MariaDB数据库 | PASS |
| node03 | etcd与Control Plane配置 | PASS |
| node04 | Kubernetes Worker配置 | PASS |
| node05 | Prometheus、Grafana与Loki | PASS |

隔离恢复目录不会覆盖生产服务目录，恢复验证完成后会检查原服务状态。

## 正式版本

当前正式版本：

```text
v1.0.0
```

目标提交：

```text
db70457fc68052fc87be95758776743db1832864
```

Release页面：

```text
https://github.com/fu-Del/enterprise-ansible-platform/releases/tag/v1.0.0
```

## 项目亮点

- 基于Role的模块化设计
- 六节点统一自动化管理
- 服务部署、监控、日志和备份全链路整合
- Kubernetes Control Plane与Worker分离
- etcd快照和Kubernetes配置双重保护
- 备份文件本地与远端SHA256校验
- 统一保留策略和容量保护
- 备份不止可生成，还经过隔离恢复验证
- Vault、`no_log`和Git历史联合安全审计
- 核心Playbook第二次执行`changed=0`
- 具备完整验收证据和GitHub正式Release

## 使用说明

本项目用于自动化运维实践、技术验证和面试项目展示。

部署到其他环境前，应当：

1. 修改Inventory主机和地址。
2. 重新创建环境专属Vault变量。
3. 替换SSH公钥。
4. 审查防火墙、SELinux和存储路径。
5. 在测试环境完成语法检查和check mode验证。
6. 确认备份服务器容量和保留策略。
7. 完成隔离恢复演练后再用于正式环境。
