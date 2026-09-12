# DIET 飯 — 可操作 MVP

這是以台大公館生活圈為背景的 responsive web app。資料保存在同一個瀏覽器的 localStorage；所有用戶、價格、餐點、行程、時間、訊息和交易皆為示範。沒有真實金流、即時 GPS 或 LLM 呼叫。

## 1. 開始操作

- Demo A：首頁 → 幫我想吃什麼 → 選心情/預算/時間 → 就吃這個 → 確認 → 開始找人幫我帶 → 確認查看訂單。
- Demo B：我知道我要吃什麼 → 搜尋「藍家割包」 → 選餐 → 編輯餐點備註、餐費、代買費、位置、deadline → 媒合。
- Demo C：我可以順便帶 → 建立行程 → 接單（或同店組合） → 訂單 → 選訂單 → Runner 視角 → 逐步更新狀態。
- Demo D：右下「我餓了」 → 輸入「我今天不想吃太油，150 元內，而且希望 40 分鐘內吃到。」 → 輸入「第二個好了。」 → 確認需求 → 媒合。
- 完成交付：切 Runner 視角逐步前進至「已抵達」，切 Buyer 查看 4 位取餐碼，再切 Runner 輸入正確碼完成。錯碼不會完成訂單。
- 售完：Runner 在購買前按「餐點售完」，切 Buyer 接受同店替代價格或取消。未确认前不能繼續配送。
- 聊天：同裝置切換角色即可互相傳訊；不會傳給真實人物。
- 如果示範需求已超時，可到「我的 → 重設 Demo 資料」重新生成相對現在的時間。

## 2. 技術與專案結構

採用 React 19 + TypeScript + Tailwind 4 + shadcn/ui，使用 Next.js App Router 相容的 Vinext starter 部署於 Sites / Cloudflare Workers。不是原生手機 App。具有 manifest、獨立視窗 metadata 和 network-only service worker；完整離線模式、所有裝置安裝相容性未驗證。

- app/page.tsx：首頁、推薦、搜尋、需求確認、媒合、Runner、訂單 timeline、聊天、Nearby、Profile。
- app/globals.css：綠色/柑橘色食物主題與手機版底部 navigation。
- app/layout.tsx：語言、標題、favicon、manifest。
- lib/diet/engine.ts：型別、seed、query parser、recommendation、match、order transitions、Repository interface。
- lib/diet/engine.test.mjs：交易與篩選邊界測試。
- docs/schema.sql：Supabase/PostgreSQL 目標 schema 與 deny-by-default RLS 基礎。
- public/meal.png：AI 生成的便當示意圖，非實際商家餐點。
- public/manifest.webmanifest、public/sw.js：基本 PWA metadata。
- .openai/hosting.json：Site identity；不可沿用到另一個新 Site。

UI 與確定性 domain functions 已分開；目前 Repository 是同步 local adapter。改成 server repository 時，需將呼叫邊界轉 async、移除角色模擬，並在 server 重新檢查權限與所有交易條件。

## 3. Demo Data / Schema

10 users、15 restaurants、30 foods、10 demands、8 routes。單一帳號 Gary 可扮演 Buyer 和 Runner，另可切換視角觀察模擬對手方。這是教學沙盒，角色切換不是認證。

本機以 DB JSON 文件保留 users/restaurants/foods/routes/orders/profile/groupMembers。目標 PostgreSQL schema 包含 profiles、saved_locations、restaurants、foods、runner_routes、orders、order_secrets、order_events、messages、ratings、meal_groups、group_members、food_history。

schema 尚未執行，也不是即開即用的 Supabase 整合。未開放的 RLS 資料表預設拒絕存取，需補上受控 RPC 和權限測試。

## 4. AI Meal Agent 架構

目前是 deterministic agent demo，沒有呼叫 LLM，不宣稱具備任意自然語言理解。

流程：自然語言 parser → Query → recommend meals（查詢 foods/restaurants/routes）→ Top 3 與可追溯理由 → 選擇 index → 需求草稿 → 使用者確認 → publish demand → match → order state。

支援數字預算、分鐘、清爽/少油、湯、重口味、素食、不吃辣、不吃雞牛豬魚與「第一/第二/第三個」。不支援的文字不會變成任意資料庫命令。

未來 AI tools 建議：search_meals、get_profile、find_runner_candidates、prepare_demand、suggest_replacement。正式 create_demand/accept_order/verify_pickup 只能交由 authenticated backend 執行。

API adapter 位置：新增 lib/diet/ai-provider.ts 與 app/api/agent/route.ts；從 page.tsx 的 agentSend 接入。所有 key 放 server env。模型返回的候選、price、deadline 必須重新從 canonical database 驗證；不接受 LLM 宣稱已付款/已接單作為交易事實。

額外暴露 read-only WebMCP tool diet_recommend_meals，與 UI 共用推薦引擎。未支援 WebMCP 的瀏覽器會略過。

## 5. Recommendation

先做 hard filters：有庫存、餐費+25 代買費 <= 預算、食材排除、素食、不吃辣、清爽不油炸、有可行 Runner、ETA <= 時間上限。

再算 normalized weighted score：個人偏好 25%、Runner availability 25%、等待時間 15%、價格 15%、距離 10%、飲食多樣性 10%。高蛋白/增肌、減脂/清爽與均衡是標籤偏好，不是營養估算。香菜以備註告知商家；沒有過敏安全保證。

不把 heuristic 分數寫成真實媒合機率。UI 顯示「幾位符合条件的人選」與模擬適配分，而非 88% 成功率。

冷啟動使用 profile + 當下條件；完成訂單後記錄最近 7 個餐點類別。心情與價格/時間的改動即時重新篩選。

## 6. Matching

以 mock 平面座標計算 Euclidean distance（示範公里），行走換算 12 分鐘/km，加 12 分鐘買餐時間與每筆 active order 4 分鐘。

額外繞路 = max(0, ceil((start→store + store→buyer + buyer→end − start→end) ×12))。

Hard filters：非本人需求、指定商家相容、繞路 <= 上限、ETA <= deadline、active orders < capacity。

排序：基礎分 + 繞路餘裕 + fee + rating，封頂 99。這不是 calibrated probability。

同店組合接單逐筆重新驗證容量與 ETA，採簡化時間緩衝；尚非多站路線最佳化。團體訂單可加入、模擬其他人加入並以滿團價建立個人需求，尚未完成全團共用單一 Runner 的原子媒合。

Maps integration：將 engine.ts 的 distance/matches 路段估算改為 lib/diet/maps-provider.ts；接地理編碼、道路 travel-time matrix、快取與失敗降級。自訂地點現以台大中心估算。

## 7. 訂單與交易邏輯

Searching(0) → Matched(1) → Heading(2) → AtRestaurant(3) → Purchased(4) → Delivering(5) → Arrived(6) → Completed(7)。取消獨立 flag。

accept：再次檢查 searching 狀態、容量與 match eligibility，防重複接單。
advance：只前進一階，售完替代未確認時阻擋；Purchased 減庫存；Arrived 必須正確碼才能 Completed。只有完成後計入收益，紀錄 completedAt。

本機碼為明文以便教學。正式版必須 server 產生、hash、限制失敗次數、只對 Buyer 顯示、server 驗證。訂單/庫存/容量操作需 database transaction + row locks + idempotency。LocalStorage 不能防使用者竄改，不可用於真實交易。

Payment integration：新增 server payment adapter、payment intent + webhook signature verification、refund/reconciliation 狀態；不要將付款成功與配送完成混為一談。UI 的「付款方式」是明示 placeholder。

## 8. 已完成

- 5 個主 navigation、三大首頁入口、手機版 layout。
- Top 3 推薦、篩選、換一批、排除類別、規則式自然語言。
- 店家/料理搜尋、餐點備註、費用與 deadline 表單、確認。
- 可視化模擬媒合與無人符合的 failure path。
- Runner 行程、可接需求、同店組合接單、容量限制。
- 8 階段訂單 timeline、取餐碼、錯碼阻擋、完成後雙方星級/標籤評價。
- 角色聊天、快速訊息、售完替代/取消、新價格確認。
- Nearby 列表與可點選的示範座標圖。
- 簡化團購加入/門檻費率、Profile/preferences/收益/歷史、local persistence/reset。

## 9. 尚未完成與限制

- 真實多人同步、登入/授權、Supabase repository、Realtime、反作弊。
- 真實 LLM、記憶學習、天氣 API、餐廳營業/菜單/庫存即時來源。
- GPS/道路地圖、多單最佳化、可靠送達時間與校準成功率。
- 團體訂單共用 Runner 的 transactional matching、完整價格變動協商、退款與爭議處理。
- 金流、推播、電話驗證、真正營養資料、醫療飲食建議。
- 離線完整操作、全面行動裝置/瀏覽器驗證。

本版本能從推薦一路操作到取餐完成；所有對手方回覆由同機模擬，不是真實服務。

## 10. 本機執行

需要 Node.js >=22.13、pnpm 及 lockfile 指定版本。先看 package.json 的 packageManager。

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm dev
```

依終端顯示的 URL 開啟。此專案的 Sites 執行設定在受管環境使用專用 launcher；一般機器請閱讀 starter scripts 的 portable 支援，必要時先執行 Sites configure-execution-profile 腳本。不要複製他人的 .sites-runtime。

```sh
node node_modules/typescript/bin/tsc --noEmit
node --experimental-strip-types lib/diet/engine.test.mjs
pnpm build
```

## 11. 部署

目前已使用 Sites 私人部署。後續 Sites 修改保留 .openai/hosting.json identity，build → commit/push → save version → deploy。其他環境可評估現有 Vinext/Cloudflare build；不是未調整即可使用的 Vercel Next.js build。

若遷移到標準 Next.js，保留 app/components/lib，將 build/dev 切為 next build/next dev，處理 Sites starter worker 專用程式，再加入環境變數、Supabase adapters 和測試。

## 12. 下一階段

先在單一宿舍用邀請制驗證需求與 Runner 供給；同步補上 Supabase Auth、RLS、server transactions 和 Realtime。再串地圖/菜單來源，最後接 LLM 的受限工具呼叫。衡量任務完成率、決策時間、媒合等待時間、取消率與每次推薦成本。

## 13. QA 實際結果

- TypeScript noEmit 通過。
- engine.test.mjs 通過：資料數量、預算/時間/素食/少油條件、無結果、重複接單、容量、逾期、完整狀態、庫存扣減、售完阻擋、錯碼阻擋。
- 桌面瀏覽器實際操作：自然語言 150 元/40 分鐘 → 第二個餐點 → 確認 → 媒合成功 → Runner 進度 → 售完 → Buyer 同店換餐 → 取餐錯碼 → 正確碼完成 → 評價。
- 桌面瀏覽器實際操作：Runner 建立行程 → 同店組合接 2 單 → 訂單列表 → 雙方快速聊天 → reload 後訊息仍存在。
- 指定「藍家割包」搜尋顯示正確的兩道示範餐點。
- 首頁與媒合成功畫面已檢視；響應式 CSS 已實作，未做實機或所有手機 viewport 的瀏覽器驗證。
- WebMCP feature detection 已加入，但測試瀏覽器未提供 modelContext，因此不能驗證工具的實際註冊/呼叫；不影響 UI。

原始碼 ZIP 可從「我的」下載。ZIP 不含 node_modules、build output、認證資料或目前 Site identity；可按本機執行步驟安裝依賴。
