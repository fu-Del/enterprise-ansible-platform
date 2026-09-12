# 企业级Ansible项目常见面试问答

## 1. 为什么使用Ansible？

Ansible采用无Agent架构，主要通过SSH管理Linux节点，部署简单。Playbook和Role使用YAML描述期望状态，适合基础环境标准化、批量配置和重复执行。

## 2. 为什么拆分Role？

Role可以把任务、模板、变量、文件和Handler组织在独立边界内。这样既能复用组件，也能单独测试某个服务，避免大型Playbook难以维护。

## 3. Inventory如何设计？

按业务角色划分`web`、`database`、`k8s`、`monitoring`和`backup`，同时使用`allservers`执行公共任务，并使用`k8s_master`和`k8s_worker`区分集群职责。

## 4. group_vars与host_vars有什么区别？

`group_vars`保存同一组主机共享的变量，`host_vars`保存节点特有变量。敏感值单独存放在Vault文件中。

## 5. 如何保证Playbook幂等？

优先使用Ansible声明式模块，避免无条件Shell修改；命令任务配置准确的`changed_when`；模板和Handler只在内容变化时触发。最终通过连续两次真实执行确认第二次`changed=0`。

## 6. check mode遇到了什么问题？

只读的command任务默认可能在check mode下被跳过，导致注册变量为空、后续断言失败。解决方法是为必须执行的只读检查增加`check_mode: false`和`changed_when: false`。

## 7. 为什么不能只检查systemctl active？

`active`只能证明进程存在，不能保证应用完成初始化或接口可用。因此还检查Prometheus、Grafana、Loki和Kubernetes的应用级健康接口。

## 8. Prometheus与Node Exporter的数据方向是什么？

Prometheus采用Pull模式，主动抓取Node Exporter的`/metrics`接口。Node Exporter不会主动把数据推送给Prometheus。

## 9. Promtail与Loki的数据方向是什么？

Promtail读取本地日志文件并主动推送到Loki。Grafana通过LogQL查询Loki。

## 10. 为什么备份服务器单独部署？

避免业务节点故障时同时丢失本地备份，也便于统一实施目录规范、容量保护、权限控制、状态汇总和保留策略。

## 11. 如何保证备份传输完整？

客户端生成本地SHA256，传输到node06后再次验证远端SHA256。只有生成、传输和校验全部成功才认为备份成功。

## 12. 为什么还需要恢复演练？

备份文件存在不代表可以恢复。恢复演练可以发现文件损坏、版本不兼容、备份内容不完整和恢复脚本逻辑错误。

## 13. MariaDB如何进行隔离恢复？

将备份恢复到独立数据目录，使用独立端口或Socket启动临时实例，验证数据库和业务对象后停止临时实例，全程不覆盖生产数据目录。

## 14. etcd备份包含什么？

包含etcd snapshot，同时归档Kubernetes Control Plane配置和集群元数据。恢复演练先验证快照状态和恢复目录，不直接覆盖运行中的etcd。

## 15. Ansible Vault保护了什么？

Vault用于加密数据库密码、Grafana敏感配置等变量。仓库只保存加密后的Vault文件，不保存Vault密码文件。

## 16. 为什么还需要no_log？

即使变量由Vault加密，任务执行时模块参数仍可能出现在日志里。`no_log: true`用于阻止敏感任务输出凭据。

## 17. 如何审计Git历史中的凭据？

除了扫描当前工作区，还遍历Git提交历史，查找password、secret、token和private key等高风险模式，并对候选结果进行脱敏和人工分类。

## 18. 为什么使用Git LFS？

Prometheus、Loki和Promtail等二进制文件较大。Git LFS把大型文件内容存放在LFS对象存储中，Git提交只保存指针，避免普通Git历史持续膨胀。

## 19. Git LFS迁移有什么风险？

迁移历史会改变提交哈希，因此迁移后必须重新核对分支、标签和Release，并执行全新克隆验证。

## 20. 项目如何证明最终成功？

项目保留了静态检查、安全审计、幂等性、服务健康、备份、恢复、GitHub Release和文档验收报告。最终结果包括第二次执行`changed=0`、备份Playbook 7/7通过、五类隔离恢复通过。
