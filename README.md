# Creo 12 材料面板（Windows）

新电脑的一句话：“请从我的 GitHub 私有仓库 raze123swq-lab/creo-material-picker 安装 Creo 材料面板，按照 AGENTS.md 检查环境、安装、验证并打开。”

新电脑需要 Windows 64 位、Creo Parametric 12.x 和该私有仓库的读取权限。独立环境检查入口为 Check.ps1。

面板支持中文分类搜索、牌号和密度说明、应用材料后显示质量，以及独立的「读取当前质量 (g)」按钮。读取按钮使用零件已有材料。面板读取本次更新的同名质量报告；检测到未赋材或零密度时提示应用材料。超时可检查 Creo 的工作目录，并通过「报告目录」指定位置。随包有 28 个通用材料和 11 个厂商牌号，其余材料从新电脑的 Creo 安装扫描。

下载仓库后执行 Install.cmd；自动执行时用 Windows PowerShell 5.1 运行 Install.ps1。安装范围为当前 Windows 用户。支持 Creo Parametric 12.x、默认用户映射键目录及本地盘符路径。已有其他配置的用户可传入 -CreoRoot 和 -Settings。

打开一个零件，关闭模态窗口，双击桌面「Creo 材料面板（便携版）」，选择材料并点击应用。面板通过切换前台窗口发送映射键，必须保持目标零件活动。随包 28 项仅用于典型密度估算，其余来自本机 Creo 安装。

## Codex 验收流程

1. 确认 Windows、Creo 12 和本仓库文件可用。检查 Creo 是否运行；如有未保存工作，等待用户保存退出。
2. 从仓库目录运行 powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Install.ps1。检查退出码。读取桌面快捷方式目标、index.csv 和 mapkeys.pro，逐项比对源文件存在、键名唯一及命令数。
3. 启动面板并检查窗口。启动 Creo，在临时目录新建毫米制零件，建立 10 mm 实心立方体。在面板选择 01_Plastics 下的 ABS，点击应用。在 Creo 读回 ABS 和重新计算的质量，换算为克并与 1.05 g 比较。若许可证、界面或读回不可用，记录具体阻塞并标记待验证。不要在用户现有模型上试改。
4. 报告实测项目、安装路径、备份及兼容性限制。重装会替换本插件标记的映射键段，并保留旧配置备份。

