# 企业级Ansible项目面试演示手册

## 演示目标

在15分钟内展示项目的架构、自动化能力、运行状态、安全设计、备份恢复能力和工程质量。

演示过程中不修改生产配置、不输出Vault内容、不展示SSH私钥。

## 演示前准备

```bash
cd /data/ansible-project

git status --short
ansible --version
ansible-inventory --graph --ask-vault-pass
```

确认：

- master01能够访问node01～node06
- Vault密码可用
- 所有节点在线
- node05监控平台正常
- node06备份目录正常
- 浏览器已打开GitHub仓库和Release页面

## 时间安排

| 时间 | 演示内容 |
|---|---|
| 0～2分钟 | 项目背景和架构 |
| 2～4分钟 | Inventory与Role设计 |
| 4～6分钟 | 六节点连通性和服务状态 |
| 6～8分钟 | Kubernetes集群 |
| 8～10分钟 | Prometheus、Grafana、Loki |
| 10～12分钟 | 统一备份与恢复演练 |
| 12～14分钟 | Vault、安全与幂等性 |
| 14～15分钟 | GitHub Release和项目总结 |

## 第一部分：项目介绍

推荐表述：

> 这是一个使用Ansible管理六台Enterprise Linux节点的自动化运维项目。项目覆盖Nginx、MariaDB、Kubernetes、Prometheus、Grafana、Loki、统一备份和隔离恢复。除了完成部署，我还进行了幂等性验证、敏感信息审计、备份恢复演练和GitHub正式发布。

打开：

```text
README.md
docs/architecture/platform-overview.md
```

重点说明：

- master01是Ansible控制节点
- node01和node02承担Web与数据库服务
- node03和node04组成Kubernetes集群
- node05承担监控日志平台
- node06作为独立备份服务器

## 第二部分：Inventory与Role设计

执行：

```bash
ansible-inventory \
--graph \
--ask-vault-pass
```

展示关键分组：

```text
allservers
web
database
k8s
k8s_master
k8s_worker
monitoring
backup
log_clients
```

查看Role：

```bash
find roles \
-mindepth 1 \
-maxdepth 1 \
-type d \
-printf '%f\n' |
sort
```

推荐表述：

> 我没有把所有任务放在一个Playbook里，而是按照服务拆分Role，再由Playbook进行编排。公共变量、组变量和节点变量分层保存，使同一套Role可以复用到不同节点。

## 第三部分：节点连通性

执行：

```bash
ansible allservers \
-m ansible.builtin.ping \
--ask-vault-pass
```

预期：

```text
node01～node06全部SUCCESS
ping: pong
```

## 第四部分：业务服务状态

Nginx：

```bash
ansible node01 \
-b \
-m shell \
-a 'systemctl is-active nginx && nginx -t' \
--ask-vault-pass
```

MariaDB：

```bash
ansible node02 \
-b \
-m shell \
-a 'systemctl is-active mariadb; mariadb-admin ping' \
--ask-vault-pass
```

预期：

```text
Nginx configuration test successful
mysqld is alive
```

## 第五部分：Kubernetes状态

执行：

```bash
ansible node03 \
-b \
-m shell \
-a '
set -e
systemctl is-active kubelet
kubectl --kubeconfig=/etc/kubernetes/admin.conf get --raw=/readyz
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A
' \
--ask-vault-pass
```

重点说明：

- node03为Control Plane
- node04为Worker
- etcd和kube-apiserver以静态Pod运行
- Calico负责集群网络
- Kubernetes配置任务支持check mode和重复执行

## 第六部分：监控日志平台

检查node05：

```bash
ansible node05 \
-b \
-m shell \
-a '
set -e
systemctl is-active prometheus
systemctl is-active grafana-server
systemctl is-active loki
curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:3100/ready
' \
--ask-vault-pass
```

检查Promtail到Loki：

```bash
ansible log_clients \
-b \
-m shell \
-a '
set -e
systemctl is-active promtail
systemctl is-enabled promtail
curl --connect-timeout 3 --max-time 5 \
-fsS http://192.168.11.15:3100/ready
' \
--ask-vault-pass
```

打开：

```text
docs/architecture/monitoring-logging-flow.md
```

重点说明：

- Prometheus主动抓取Node Exporter
- Promtail主动推送日志到Loki
- Grafana分别通过PromQL和LogQL查询
- 监控和日志共用Grafana展示，但数据存储相互独立

## 第七部分：备份体系

打开：

```text
docs/architecture/backup-recovery-flow.md
```

检查node06：

```bash
ansible node06 \
-b \
-m shell \
-a '
set -e
test -d /backup/data
test -x /usr/local/bin/backup-status-report
crontab -l -u root |
grep -E "backup-status-report|backup-retention-cleanup" || true
df -h /backup/data
' \
--ask-vault-pass
```

推荐表述：

> node01到node05在本地生成备份和SHA256，通过专用SSH密钥传输到node06。node06负责远端校验、容量保护、状态汇总、保留策略和过期清理。

## 第八部分：恢复演练

推荐表述：

> 我没有把“备份文件存在”当成备份成功，而是为Nginx、MariaDB、etcd、Kubernetes Worker配置以及监控日志平台分别进行了隔离恢复。恢复过程使用独立目录或临时实例，不覆盖当前生产服务，最后还会检查原服务健康状态。

恢复结果：

| 节点 | 恢复对象 | 结果 |
|---|---|---|
| node01 | Nginx配置与站点 | PASS |
| node02 | MariaDB逻辑备份 | PASS |
| node03 | etcd及Control Plane配置 | PASS |
| node04 | Kubernetes Worker配置 | PASS |
| node05 | Prometheus、Grafana、Loki | PASS |

## 第九部分：幂等性与安全

查看幂等性报告：

```bash
find reports/phase9 \
-type f \
-name 'phase9-5-final-summary.txt' \
-exec cat {} \;
```

重点结果：

```text
Backup playbooks: 7/7 PASS
Second-run changes: 0
Failed hosts: 0
Unreachable hosts: 0
Result: PASS
```

安全设计：

- Vault文件保持加密
- Vault权限为0600
- Vault密码文件不进入仓库
- SSH私钥不进入仓库
- 敏感任务使用`no_log: true`
- Git当前版本和历史均执行明文凭据审计

不要在面试过程中执行：

```bash
ansible-vault view
cat /root/.ssh/github_ed25519
ansible-playbook -vvv
```

## 第十部分：GitHub工程化

展示：

```text
README.md
docs/architecture/
GitHub Pull Requests
GitHub Release v1.0.0
```

说明：

- 大文件使用Git LFS
- 功能代码通过版本标签发布
- 文档通过独立分支和PR合并
- `v1.0.0`标签保持不可变
- 正式Release经过全新克隆和LFS验证

## 结束总结

推荐表述：

> 这个项目的重点不只是会写Ansible Playbook，而是把部署、监控、日志、备份、恢复、安全审计、幂等性和版本发布形成了完整闭环。项目最终实现六节点统一管理，核心Playbook二次执行changed为0，七个备份Playbook全部通过，并完成五类隔离恢复验证。
