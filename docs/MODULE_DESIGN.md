# Farm Match — 前后端模块技术说明

> 对齐架构方案 v1.1.1，并以文末 **§8** 与 `GAME_FEATURES.md` v1.1（§3.7.1 / §3.7.1b / §5.14）、`TECH_ARCHITECTURE.md` 修订附记 v1.2 覆盖旧的「不做云同步」句子。  
> 2026-10-09｜开发  
> Notion：[前后端模块技术说明](https://app.notion.com/p/3f429db626158135995ee327fef1fae0)

---

## 0. 设计原则

1. **功能内聚、依赖单向**：UI → 应用用例 → 领域 → 数据/基础设施；禁止反向依赖  
2. **接口隔离**：商店、网络、本地存储都走抽象，便于单测与换实现  
3. **后台薄、客户端厚**：玩法与进度在客户端；服务端只做可信任边界（验单、配置）  
4. **配置驱动扩展**：新商品/关卡段优先走远程 config + 本地 entitlements，少改发版逻辑  
5. **失败可降级**：config / 验单失败有明确本地默认与重试，不堵死开玩  

---

## 1. 总览

```
farm_match_app/          # Flutter
  lib/
    app/                 # 组装、路由、DI
    core/                # 横切：错误、日志、主题、常量
    features/            # 按功能竖切
    shared/              # 跨 feature 小组件/工具

farm_match_api/          # NestJS
  src/
    main.ts
    app.module.ts
    config/              # 远程配置模块
    iap/                 # 验单模块
    common/              # 过滤器、守卫、限流、日志
    infrastructure/      # DB、HTTP 出网（Apple/Google）
```

运行时：`Flutter features` ←HTTPS→ `API config | iap` → `Postgres` + `Apple/Google`

---

## 2. 客户端（Flutter）架构

### 2.1 分层（每个 feature 内部）

| 层 | 目录约定 | 职责 |
|----|----------|------|
| Presentation | `presentation/` | 页面、Widget、Riverpod/Bloc；只渲染与派发意图 |
| Application | `application/` | 用例（UseCase）：改昵称、过关、购买、Restore |
| Domain | `domain/` | 实体、值对象、仓库接口；无 Flutter/HTTP 依赖 |
| Data | `data/` | 仓库实现、DTO、本地源、远程源 |

状态管理建议：**Riverpod**（或 Bloc，全项目统一一种）。导航：`go_router`。

### 2.2 Feature 模块清单

#### `identity`

- **域**：`LocalUser`（id、nickname、createdAt）  
- **用例**：`BootstrapIdentity`（首次生成）、`UpdateNickname`  
- **存储**：`flutter_secure_storage` / Hive / Isar；昵称可普通本地 DB  
- **扩展点**：绑定登录走 `auth` 的 `AuthPort`，不改玩法  

#### `progress`（本机进度）

- **域**：`clearedLevel`、关卡统计、settings（muted 等）  
- **用例**：`LoadProgress`、`SaveProgress`、`ClearLevel`  
- **规则**：游客只写本机，卸载不找回。已绑定后由 `cloud_save` 同步最高通关（见 §8）  

#### `inventory`

- **域**：`move` / `undo` / `shuffle` 次数  
- **用例**：`ConsumeTool`、`GrantTools`（购后发放）  
- **规则**：消耗型；Restore **不**恢复次数  

#### `entitlements`

- **域**：`removeAds`、`unlockedLevelMax`（或 `ownedBundles: {barn, harvest}`）  
- **用例**：`ApplyPurchase`、`RestoreEntitlements`  
- **规则**：非消耗；Restore 只刷新本模块  
- **门闸**：`LevelGate.canPlay(level)` 供 game/home 查询  

#### `iap`

- **依赖**：商店 SDK 抽象 `StoreClient`（StoreKit2 / Play Billing 实现）  
- **流程**：`PurchaseProduct` → 拿凭证 → `IapApi.verify` → 成功则调 `entitlements` / `inventory`  
- **错误**：用户取消、待处理、验单失败分错误码；UI 不直接碰 SDK  

#### `config`

- **远程**：`GET /v1/config`  
- **本地**：内置 `default_config.json` 兜底 + 缓存上次成功响应  
- **用例**：`RefreshConfig`（启动、进前台）  

#### `game`

- **域**：牌面、托盘、匹配规则、关卡生成（可由现有 HTML 逻辑迁移）  
- **依赖**：`progress`、`inventory`、`entitlements`（只读门闸）、`config`  
- **禁止**：直接调商店或 HTTP；购相关走 iap/entitlements  

#### `home` / `store_ui` / `settings`

- 首页方钮未解锁 → 拉起 store 购买提示  
- Settings：改昵称、账号绑定状态、好友互赠入口、英文按钮 `Restore Purchases`、静音等  

### 2.3 客户端目录示例

```
lib/features/iap/
  domain/entities/product.dart
  domain/repositories/iap_repository.dart
  application/purchase_product.dart
  application/restore_purchases.dart
  data/store_client.dart
  data/iap_api.dart
  data/iap_repository_impl.dart
  presentation/store_page.dart
```

### 2.4 客户端扩展指南

- **新道具**：config 商品表 + inventory 字段 + UI；验单发放表驱动  
- **新关卡段包**：config + entitlements 映射表；门闸自动生效  
- **换状态库 / 换本地 DB**：只改 data 与 DI 绑定  

---

## 3. 服务端（NestJS）架构

### 3.1 模块化 + 六边形思路

每个业务模块：`Controller`（入站）→ `Service/UseCase` → `Port`（出站接口）→ `Adapter`（Postgres、Apple、Google）。

`common`：全局异常过滤、请求日志、限流、DTO 校验。

### 3.2 模块清单

#### `ConfigModule`

- `GET /v1/config?appVersion&platform`  
- 读配置 + version；可按 platform/appVersion 过滤；短缓存；必须限流  

#### `IapModule`

- `POST /v1/iap/verify`  
- Body：`platform`, `productId`, `receipt` | `purchaseToken`, 可选 `packageName`  
- 流程：校验 → Apple/Google Verifier → 查重 `store_txn_id` → 写 `orders` → 返回结果  
- **不**写用户进度；幂等：同一 txn 重复请求返回首次成功结果  

#### `InfrastructureModule`

- TypeORM/Prisma + Postgres  
- 出网 HTTP（超时、重试；普通日志不落全量敏感收据）  

#### `HealthModule`

- `GET /health` 探活  

### 3.3 服务端目录示例

```
src/iap/
  iap.module.ts
  iap.controller.ts
  application/verify-purchase.usecase.ts
  domain/order.ts
  domain/ports/store-verifier.port.ts
  domain/ports/order-repository.port.ts
  infrastructure/apple-verifier.adapter.ts
  infrastructure/google-verifier.adapter.ts
  infrastructure/order.repository.ts
  dto/verify-purchase.dto.ts
```

### 3.4 数据表（最小）

- `orders(id, platform, product_id, store_txn_id UNIQUE, status, raw jsonb, created_at)`  
- `config_entries(id, version, payload jsonb, updated_at)`  

### 3.5 服务端扩展指南

- **新 SKU**：商店建商品 + config 表；一般不改表结构  
- **换云厂商**：只换部署与密钥；代码不绑腾讯 SDK  
- **账号与云档**：服务端另建 Auth / cloud save / friends 模块，勿把进度塞进 IapModule。客户端端口见 §8  

---

## 4. 模块依赖图（允许的方向）

**客户端**

- `presentation → application → domain ← data`  
- `game → progress | inventory | entitlements | config`  
- `store_ui / settings → iap → entitlements | inventory`  
- `settings → auth | gift`  
- `cloud_save → auth | progress | inventory | entitlements`  
- `gift → inventory`（仅领取入账；送出不扣库存）  
- `iap → config`  
- `game` 领域层不依赖 `auth`；过关软提示只在 game 的 presentation  

**服务端**

- `iap.controller → verify.usecase → StoreVerifierPort / OrderRepositoryPort`  
- `config.controller → config.service → ConfigRepository`  

禁止：`game` 直接依赖 Store SDK；禁止 API 模块循环引用。

---

## 5. 关键契约（摘要）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/v1/config` | 远程配置；失败客户端用默认 |
| POST | `/v1/iap/verify` | 验单；成功后客户端写本机 |
| GET | `/health` | 探活 |

账号、云档、好友互赠的客户端端口见 §8。Fake adapter 在进程内完成，游客路径不发起这些调用。Restore Purchases 仍只走商店验单，不从云档扩 scope。

错误体：`{ "code": "IAP_VERIFY_FAILED", "message": "..." }`

---

## 6. 测试与质量

- 客户端：domain/application 纯单测；iap 用 Fake StoreClient；账号提示、互赠上限、云档合并见 `test/account_friends_test.dart`  
- 服务端：verifier 夹具；订单幂等；OpenAPI 契约  
- CI：analyzer + test；禁止跨层乱引用  

---

## 7. 与架构方案的关系

总架构：[docs/TECH_ARCHITECTURE.md](./TECH_ARCHITECTURE.md)  
商品与产品规则以架构方案 + 策划功能说明为准；本文只描述代码怎么切、怎么依赖、怎么扩展。

---

## 8. 账号、云存档与好友互赠（产品 v1.1）

客户端模块 `auth`、`cloud_save`、`gift`：默认游客本机档；第 5 关过关后可跳过绑定 X/Facebook；第 8 关撤回解锁后再推绑定并邀请好友。登录后云同步进度、道具与权益。规则与 Param ID 见 `GAME_FEATURES.md` §3.7.1、§3.7.1b、§5.14；后台 API 见 `TECH_ARCHITECTURE.md` 修订附记 v1.2。Restore Purchases 仍只恢复去广告与关卡包。

### 8.1 目录

```
lib/features/auth/        AuthPort + FakeAuthAdapter，本机记住绑定与 L5/L8 跳过
lib/features/cloud_save/  CloudSavePort + FakeCloudSaveAdapter，合并后写回本机
lib/features/gift/        GiftPort + FakeGiftAdapter，邀请与每日互赠
```

每个模块仍是 `presentation → application → domain ← data`。端口在 domain，Fake 在 data，Riverpod 在 `lib/app/providers.dart` 绑定。

### 8.2 合并策略（updatedAt / max clearedLevel）

1. `highestCleared = max(local, cloud)`，通关进度不回退。  
2. Move / Undo / Shuffle 取 `updatedAt` 更新的一侧。时钟只在过关、道具数量变化、领取礼物时前进。静音、手指引导、昵称留在本机，不进云档。  
3. `updatedAt` 相同则每种道具取较大值，平局不丢次数。  
4. `removeAds`、`barnBundle`、`harvestBundle` 按或合并，已购不因另一台设备较旧而消失。这与 Restore Purchases 分开：Restore 仍只从商店拉回这三档，不恢复进度和道具。  
5. 合并结果的 `updatedAt` 取较新的时间，写回本机并 push。新安装的本地时钟是 epoch，因此云档上的道具和更高通关会被拉回。  
6. 未绑定账号时 `SyncCloudSave` 直接返回，不调用 `CloudSavePort`。拉取失败则保留本机，不拿空档覆盖云端。

### 8.3 互赠

- 当日先选定的道具类型锁定（Move / Undo / Shuffle 三选一）。  
- 免费赠送池每天最多送出 3 次，不扣自己的库存。  
- 同一好友同一天最多收 1 次。接收总次数不按 3 封顶。  
- 失败页和已解锁但次数为 0 的道具条提供英文 `Ask a friend`，进入好友页。文案不出现 “Please log in”。

## 9. 增长模块（v1.2+｜仅 App）

规则与 Param ID 见 `GAME_FEATURES.md` §3.7.1c–e、§5.15。网页原型不做。

- `invite`：邀请码生成、归因、双向发奖、日/终身上限。
- `deeplink`：Universal/App Links + scheme `farmmatch://`；延迟深链；路由表 invite / gift / challenge / shop（shop 预留，落到现有商店页）。
- `rate_prompt`：连胜与关卡钩子；In-App Review 端口；冷却与绑定/邀请弹窗互斥。
- `gift_remind`：收礼推送、晚间未送出提醒、红点、通知权限时机（§3.7.1f / §5.16）。本客户端用 `NotificationPort` + Fake 记录推送；系统通知插件后续替换 Fake。权限只在 L8 邀请流程之后或本次会话首次收礼时请求。

### 9.1 延迟深链选型

Firebase Dynamic Links 已停用。本客户端用 **安装来源 stub + 剪贴板**，CI 用 Fake：

1. 首次打开读取 `install_referrer`（Android Play Install Referrer 的替身，测试可预写这条 prefs）。读过即丢，避免二次归因。
2. 若没有来源，再看剪贴板是否为 `farmmatch://` 或 `https://farmmatch.app/...`，只在首次打开尝试一次。
3. 自定义 scheme `farmmatch://invite|gift|challenge|shop` 作已安装时的兜底。通用链接形态为 `https://farmmatch.app/<type>`。
4. 冷启动：解析链接 → 游客身份就绪 → 再 `go` 到意图页。解析失败留在首页。

| 类型 | 例子 | 落地 |
|------|------|------|
| invite | `farmmatch://invite?code=FARM-1000` | 首页轻提示去打第 1 关，并记下邀请码 |
| gift | `farmmatch://gift?from=Sunny&type=undo` | 好友礼物页 |
| challenge | `farmmatch://challenge?level=12` | 已解锁则进该关，否则停在首页 |
| shop | `farmmatch://shop?sku=barn_bundle` | 预留；打开商店并聚焦 SKU |
