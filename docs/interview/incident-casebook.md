# 项目故障案例手册

## 案例一：Inventory YAML缩进损坏

### 现象

```text
Unable to parse inventory/hosts.yml
did not find expected key
No inventory was parsed
```

### 原因

编辑Inventory时破坏了YAML层级，`children`、`hosts`和节点名称没有保持正确缩进。

### 处理

1. 使用`nl -ba inventory/hosts.yml`定位行号。
2. 恢复`all.children.<group>.hosts`层级。
3. 补充`allservers`、`k8s_master`和`k8s_worker`分组。
4. 使用`ansible-inventory --graph`验证。

### 结果

```text
allservers: node01～node06
k8s_master: node03
k8s_worker: node04
```

### 经验

Inventory修改后必须同时执行YAML检查、Inventory解析和主机匹配检查。

---

## 案例二：Playbook主机组名称不一致

### 现象

```text
Could not match supplied host pattern, ignoring: monitor
skipping: no hosts matched
```

### 原因

Playbook使用`monitor`，Inventory实际分组名称为`monitoring`。

### 处理

统一Playbook和Inventory中的组名，并执行：

```bash
ansible-playbook playbooks/prometheus.yml \
--list-hosts \
--ask-vault-pass
```

### 经验

`--syntax-check`通过不代表一定能匹配目标主机，必须配合`--list-hosts`。

---

## 案例三：Promtail配置路径判断错误

### 现象

```text
systemctl is-active promtail: active
systemctl is-enabled promtail: enabled
test -s /etc/promtail/promtail.yml: failed
```

### 原因

实际配置文件为：

```text
/etc/promtail/promtail.yaml
```

验证命令错误地检查了`.yml`。

### 处理

从systemd的`ExecStart`读取真实配置路径，并统一Role、服务文件和验证命令。

### 经验

不能只凭经验猜测配置路径，应以systemd启动参数作为事实来源。

---

## 案例四：Loki就绪接口返回503

### 现象

```text
curl http://127.0.0.1:3100/ready
HTTP 503
at least 1 live replicas required
```

Promtail日志同时出现：

```text
Internal Server Error
unhealthy instances
no route to host
```

### 原因

Loki进程虽然处于active状态，但内部Ring或实例健康状态尚未就绪。

### 处理

1. 检查Loki配置和数据目录。
2. 检查服务日志。
3. 等待Loki完全就绪。
4. 使用带重试的ready检查。
5. 再检查Promtail最近日志。

### 经验

`systemctl is-active`只能说明进程存在，不能代表应用已经可以提供服务。

---

## 案例五：Ansible check mode跳过命令导致断言失败

### 现象

```text
Verify SELinux is enforcing: skipped
Assert SELinux enforcing: FAILED
```

CPU检查也出现相同问题。

### 原因

`ansible.builtin.command`在check mode下默认被跳过，注册变量没有真实输出，后续断言基于空值失败。

### 处理

为只读检测命令增加：

```yaml
changed_when: false
check_mode: false
```

### 结果

SELinux、CPU、Kubernetes API和etcd健康检查均能在check mode中正确执行。

### 经验

check mode兼容性需要单独设计，不能假设所有模块都会正常执行。

---

## 案例六：Role错误包含完整Playbook

### 现象

```text
ERROR! conflicting action statements: hosts, gather_facts
```

### 原因

Role的任务文件错误地包含了带有`hosts`和`gather_facts`的完整Playbook。

Role任务文件只能包含任务列表，不能包含Play级关键字。

### 处理

将服务配置拆分成Role任务文件，由顶层Playbook负责`hosts`、权限提升和Role编排。

### 经验

Playbook负责“在哪些主机执行”，Role负责“执行哪些可复用任务”。

---

## 案例七：Loki版本不支持配置验证参数

### 现象

```text
Loki does not support -verify-config
```

### 原因

当前Loki版本没有该命令行参数。

### 处理

根据实际版本能力调整验证方式，结合：

- 服务启动状态
- ready接口
- 日志检查
- 配置文件存在性
- 数据目录检查
- Promtail端到端推送检查

### 经验

不同版本的软件参数可能发生变化，验证脚本必须与实际二进制版本匹配。

---

## 案例八：MariaDB恢复脚本返回非零

### 现象

恢复脚本返回`rc=1`，但生产MariaDB仍然正常：

```text
active
mysqld is alive
TEMP_INSTANCE_STOPPED
```

### 原因分析

部分数据库备份文件没有`CREATE TABLE`和`INSERT`，只有`web_db`包含实际业务对象。验证逻辑错误地假定所有数据库都必须包含表和数据。

### 处理

根据数据库实际用途制定验证条件：

- 允许空数据库完成结构恢复
- 对有业务数据的数据库验证表和记录
- 确认临时实例停止
- 确认生产实例未受影响

### 经验

恢复验证应基于业务预期，而不是简单依赖统一的行数判断。

---

## 案例九：GitHub SSH 22端口不可用

### 现象

```text
Connection closed by remote host port 22
Could not read from remote repository
```

### 处理

使用GitHub SSH 443端口：

```text
ssh://git@ssh.github.com:443/fu-Del/enterprise-ansible-platform.git
```

并为仓库配置指定密钥：

```bash
git config --local core.sshCommand \
'ssh -i /root/.ssh/github_ed25519 -o IdentitiesOnly=yes -p 443'
```

### 经验

网络受限环境下，需要区分仓库权限错误、SSH密钥错误和端口连通性问题。

---

## 案例十：GitHub大文件需要Git LFS

### 现象

Prometheus、Loki、Promtail和Node Exporter二进制文件使普通Git对象过大。

### 处理

1. 配置`.gitattributes`。
2. 使用Git LFS迁移历史。
3. 重新确认分支和标签提交。
4. 推送5个LFS对象。
5. 从GitHub全新克隆。
6. 验证`Filtering content: 100% (5/5)`。

### 经验

Git LFS迁移可能重写提交历史，迁移后必须重新核对分支、标签和Release。
