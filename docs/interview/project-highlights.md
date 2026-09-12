# 项目技术亮点

## 一、Role模块化设计

项目按照服务拆分Role，顶层Playbook只负责编排。

价值：

- 减少重复代码
- 明确服务边界
- 支持单组件部署
- 便于幂等性测试
- 降低维护风险

## 二、变量分层

变量按照以下层级组织：

```text
Role defaults
    ↓
group_vars
    ↓
host_vars
    ↓
Vault敏感变量
```

普通配置和敏感配置分离，节点差异由`host_vars`管理。

## 三、六节点职责隔离

- 控制节点不承载业务
- 数据库和Web服务分离
- Kubernetes Control Plane和Worker分离
- 监控日志平台独立
- 备份服务器独立

这种设计减少单点故障影响，也使权限和容量管理更清晰。

## 四、完整的可观测性链路

```text
Node Exporter → Prometheus → Grafana
Promtail → Loki → Grafana
```

不仅检查进程状态，还检查ready接口和端到端网络链路。

## 五、备份完整性校验

备份流程同时验证：

- 备份源文件
- 本地SHA256
- SSH传输结果
- node06远端SHA256
- 状态汇总
- 容量保护
- 保留策略

## 六、备份与恢复闭环

项目对五类数据执行隔离恢复：

- Nginx
- MariaDB
- etcd和Control Plane配置
- Kubernetes Worker配置
- Prometheus、Grafana和Loki

恢复不覆盖生产目录，并在演练结束后确认原服务健康。

## 七、check mode兼容

针对只读命令增加：

```yaml
changed_when: false
check_mode: false
```

避免check mode跳过命令后导致注册变量为空。

## 八、幂等性验证

每个核心Playbook执行：

```text
check mode
第一次真实执行
第二次真实执行
运行健康检查
```

最终第二次执行：

```text
changed=0
failed=0
unreachable=0
```

## 九、安全审计

- Vault文件加密
- Vault权限0600
- 敏感任务`no_log: true`
- 无Vault密码文件
- 无SSH私钥
- 当前文件明文凭据扫描
- Git历史凭据扫描
- 临时敏感文件清理

## 十、可审计证据

项目为静态检查、安全审计、幂等性、恢复演练、Release和文档阶段生成独立证据报告。

这使项目结果可以复核，而不仅依赖口头描述。

## 十一、规范的Git发布流程

```text
功能分支
    ↓
本地验证
    ↓
Pull Request
    ↓
合并到main
    ↓
标签与Release
    ↓
全新克隆验证
```

大型文件通过Git LFS管理，`v1.0.0`标签在发布后保持不变。
