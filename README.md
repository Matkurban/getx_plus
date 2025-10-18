# GetX Plus

简洁、轻量的 GetX 分支：在不依赖 BuildContext 的情况下进行路由导航、状态管理与依赖注入。本项目用于继续维护原项目在上游不再及时更新的场景，同时保持 API 兼容（基于 4.7.3）。

> English summary: This is a lightweight maintained fork of GetX (version 4.7.3 baseline). Same core APIs for state, route, and dependency management. See upstream docs for full details.

## 与原项目的关系
- 上游仓库: https://github.com/jonataslaw/getx  （完整 README 与历史说明）
- 本仓库为 `getx_plus`，目标：小幅维护、问题修复、偶发增强，不做破坏性重构。
- 若需全面深入教程/高级特性，请直接跳转原 README: https://github.com/jonataslaw/getx/blob/master/README.md

## 为什么精简
原 README 内容非常庞大；这里仅保留快速上手与入口导航，降低阅读成本。深入内容 → 参见下方“详细文档”。

## 安装
在 `pubspec.yaml` 中添加：
```yaml
dependencies:
  getx_plus: ^4.7.3
```
导入：
```dart
import 'package:getx_plus/get.dart';
```

## 快速示例（计数器）
```dart
import 'package:flutter/material.dart';
import 'package:getx_plus/get.dart';

void main() => runApp(GetMaterialApp(home: Home()));

class CounterController extends GetxController {
  final count = 0.obs;
  void inc() => count++;
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Get.put(CounterController());
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text('Clicks: ${c.count}'))),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Get.to(const Other()),
          child: const Text('Go to Other'),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: c.inc, child: const Icon(Icons.add)),
    );
  }
}

class Other extends StatelessWidget {
  const Other({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<CounterController>();
    return Scaffold(body: Center(child: Obx(() => Text('Total: ${c.count}'))));
  }
}
```
核心点：
- `.obs` 创建可观察变量
- `Obx(() => ...)` 响应式刷新
- `Get.put()` 注入依赖；`Get.find()` 获取
- `GetMaterialApp` 提供路由/国际化/snackbar/dialog 能力

## 常用速查
| 场景    | 调用                       |
|-------|--------------------------|
| 跳转页面  | `Get.to(Widget())`       |
| 返回上一层 | `Get.back()`             |
| 替换当前  | `Get.off(Widget())`      |
| 清空并跳转 | `Get.offAll(Widget())`   |
| 注入依赖  | `Get.put(Controller())`  |
| 查找依赖  | `Get.find<Controller>()` |
| 状态变量  | `var x = 0.obs;`         |
| 监听刷新  | `Obx(() => Text('$x'))`  |

## 详细文档入口
本地精简索引（与原项目英文文档路径保持一致）：
- 状态管理: `documentation/en_US/state_management.md`
- 路由管理: `documentation/en_US/route_management.md`
- 依赖管理: `documentation/en_US/dependency_management.md`

多语言（文件结构已存在，可直接打开）：`documentation/<lang_code>/` 下同名文件。
示例: `documentation/zh_CN/state_management.md`

若这些文件缺少更新，请以上游 README 为准。

## 目标与原则
- 保持 API 行为兼容，减少升级风险
- 优先修复 bug & 适配新 Flutter 版本
- 不主动引入复杂生成器/宏

## 参与贡献
欢迎 issue / PR：
1. 提交前请尽量复用原风格
2. 保持向后兼容；若需破坏性变更请先开 issue 讨论
3. 添加最小化测试或示例片段

## 常见问题 (FAQ 简版)
- 需要 context 吗？大多数 GetX API 不需要
- 必须使用 `GetMaterialApp` 吗？仅在使用路由/国际化/snackbar/dialog 等功能时需要
- 与 Provider / Riverpod 能共存吗？可以，只用其依赖注入或部分能力即可

## License
沿用上游项目 LICENSE。

## 引用与致谢
感谢原作者与社区贡献者的工作： https://github.com/jonataslaw/getx

---
需要完整示例、进阶中间件、GetConnect、国际化高级用法等 → 请直接访问上游 README 或本地 `documentation/`。
