; --------------
; 初始设置
; --------------

extensions [gis table]; gis & table扩展
globals [
  countries-dataset  ; GIS数据集
  flag               ; 用来注意模型何时停止变化
  iteration          ; 循环轮数
  ]

patches-own [country-name]

breed [states state] ; 国家类
states-own [
  name           ; 国家名称
  key-feature    ; 国家主要地图特征 连续即为国家本身

  score          ; 累计分数
  init-score     ; 初始分数

  change-count   ; 状态改变次数

  play-table     ; 表，记录每个国家对每个邻国的博弈
  hegemon        ; 如果这个国家是霸权国家，true; 否则false
  init-hegemon   ; 国家最初的霸权价值
  next-strongest ; 相对自己强一位的邻居
  next-weakest   ; 相对自己弱一位的邻居
  ranking        ; 该国家在邻国中的相对排名(1为最低)
]

; ----------------
; 准备部分
; -----------------

to setup
  ;clear-all & reset-ticks
  clear-all
  reset-ticks
  set flag false    ; 设置模型运/停状态
  load-data        ; 加载数据
  draw-countries   ; 绘制数据
  generate-states  ; 生成国家代理
  build-network    ; 共享边界国家建立网络联系
  expand-network   ; 扩展网络避免孤岛
  clean-up-network ; 完善网络
end

to load-data
  ; GIS数据和用于加载它的代码
  ; "GIS General Examples," NetLogo Model Library, Wilensky 2008
  set countries-dataset gis:load-dataset "data/countries.shp"
  gis:set-world-envelope (gis:envelope-of countries-dataset) ; 设置范围

  ; 为每个patch分配其国家的名称
  gis:apply-coverage countries-dataset "SOVEREIGN" country-name ; SOVEREIGN 主权
end

to draw-countries
  ask patches [ set pcolor 96 ] ; 海洋颜色
  ; "GIS General Examples," NetLogo Model Library, Wilensky 2008
  gis:set-drawing-color 8       ; 陆地颜色
  gis:draw countries-dataset 3  ; 边界宽度
  gis:fill countries-dataset 1  ; 填充
end

to generate-states
  ; 遍历所有功能并为每个国家创建一个代理
  foreach gis:feature-list-of countries-dataset [ f ->
    ifelse any? states with [name = gis:property-value f "SOVEREIGN"]
    ; 如果存在任何名字为主权国名字的代理，这样做:
    [
      ask states with [name = gis:property-value f "SOVEREIGN"] [
        ; 如果新要素名称与国家相同(即是本土)
        if gis:property-value f "CNTRY_NAME" = gis:property-value key-feature "SOVEREIGN"
        [
          ; 定位质心，对于多边形数据集，质心定义为将区域分解为(可能重叠的)三角形的质心的加权和
          let location gis:location-of gis:centroid-of f
          set xcor item 0 location ; 经度
          set ycor item 1 location ; 纬度
         ]
      ]
    ]

    ; 否则，这样做:
    ; 创建一个新的国家代理:
    [
      create-states 1 [
        ; 初始化地理属性:
        set key-feature f
        set name gis:property-value key-feature "SOVEREIGN" ; 根据特征设置国家名
        ; 将坐标设置为质心
        let location gis:location-of gis:centroid-of f
        set xcor item 0 location
        set ycor item 1 location

        ; 初始化非地理空间属性:
        set play-table table:make ; 初始化新表
        set score 0               ; 设定初始分数
        set hegemon false         ; 所有国家一开始都是非霸权国家
        set ranking -1            ; 各国家没有默认等级

        ; 设置外观
        set shape "star"
        set size 1
        set color green
      ]
    ]
  ]
end

to build-network
  ; 构建双边（共享边界）网络
  ; 在任何两个共享边界的国家之间建立联系
  foreach gis:feature-list-of countries-dataset
  [ f ->
    let country f
    foreach gis:feature-list-of countries-dataset [ ff ->
      ; 如果至少有一个共同点则为真
      if gis:intersects? country ff and country != ff [
        let name1 gis:property-value country "SOVEREIGN"
        let name2 gis:property-value ff "SOVEREIGN"
        let country1 one-of states with [name = name1]
        let country2 one-of states with [name = name2]
        ask country1 [ create-link-with country2]
      ]
    ]
  ]
end

to expand-network
  ; 通过将每个未连接的国家连接到最近的两个国家来避免孤岛
  ask states with [count link-neighbors = 0]
  [
    foreach list 1 2 [
    let choice (min-one-of (other turtles with [not link-neighbor? myself]) [distance myself])
    if choice != nobody [create-link-with choice]
    ]
  ]
end

to clean-up-network
  ; 清空 手动整理
  ; 删除Antactica
  ask states with [name = "Antarctica"]
  [
    ask my-links [die]
    die
  ]
  ; 重命名DRC以避免CSV文件中逗号的问题:
  ask states with [name = "Congo, DRC"] [set name "DRC Congo"]

  ; 手动添加一些应该在那里的边缘（即特例）:
  let country1 one-of states with [name = "Dominican Republic"]
  let country2 one-of states with [name = "St. Kitts & Nevis"]
  ask country1 [create-link-with country2]

  set country1 one-of states with [name = "Trinidad & Tobago"]
  set country2 one-of states with [name = "Venezuela"]
  let country3 one-of states with [name = "Guyana"]
  ask country1 [
    create-link-with country2
    create-link-with country3
  ]

  set country1 one-of states with [name = "United Kingdom"]
  set country2 one-of states with [name = "France"]
  ask country1 [create-link-with country2]
end

to print-links
  ; 输出相互关系到输出区域
  clear-output
  ask links
  [
    output-print [name] of both-ends
  ]
end

to export-links
  ; 导出相互关系
  ; file-open "WorldNetwork.csv"
  file-open user-new-file
  file-type "Source,Destination\n"
  ask links [
    foreach [name] of both-ends [ f ->
      file-type f
      file-type ","
    ]
    file-type "\n"
  ]
  file-close
end

; -----------------
; 模型程序
; -----------------

to prep-model
  reset-ticks
  clear-all-plots

  ask states [
    ; 初始化非地理空间属性:
    set play-table table:make         ; 初始化新表

    ; 设定初始分数 四种方式
    if score-dist = "Normal"
    [set score random-normal 0 1]     ; 标准正态分布随机分数

    if score-dist = "Exponential"
    [set score random-exponential 10] ; 指数分布的随机浮点数，均值为10

    if score-dist = "Norm-GDP" [
      set score gis:property-value key-feature "NORMGDP" ; 标准GDP
    ]

    if score-dist = "Sum-KM2" [
      set score 0.000001 * (gis:property-value key-feature "SQKM") ; 总面积
    ]

    set init-score score
    set hegemon false
    set ranking -1                    ; 各国没有默认级别
    set change-count 0

    ; 设置图形属性
    set label precision score 1
  ]

  ; 初始化霸权
  ask states [
    ; 在连接的邻居中初始分数最大即为霸权
    if score > [score] of max-one-of link-neighbors [score]
    [ set hegemon true]
    set init-hegemon hegemon
    update-color ; 区分霸权与否
  ]
  update-plot    ; 绘图
end

to watch-most-hegemon
  ; 聚焦最大分数霸权国
  watch one-of states with [score = max [score] of states with [hegemon]]
  ask subject [
    inspect self ; 面板
    set size 2   ; 放大
  ]
end

to stop-watching
  ask turtles [
    stop-inspecting self
    set size 1
  ]
  reset-perspective
end

to go
  set flag false                  ; 停止符 停止条件为局部相对排名不变
  ask states [update-assessments] ; 更新评估
  ask states [compute-payoff]     ; 计算收益
  if TFT = true
    ; 如果选择以牙还牙方式
    [ask states [update-tit-for-tat]] ; 模仿对方
  ask states [update-color]       ; 区分霸权与否

  if not flag [stop]              ; 判断停止与否
  tick

  update-plot                     ; 更新绘图
end

to update-assessments
  ; 更新代理
  ; 评估所有的网络邻居，以找到整体的局部排名和相对自己强一位/相对自己弱一位的邻居

  set next-strongest  -1
  set next-weakest  -1

  let temp-rank 0

  ; 找到相对自己强一位/相对自己弱一位的邻居
  foreach [who] of link-neighbors
  [ f ->
    let other-score [score] of state f
    ifelse other-score > score
    [
      ; 如果这个国家的分数比我高
      ifelse next-strongest > 0
        [
          ; 如果该国家的分数低于当前的最高分数(如果已指定最强)
          if other-score < [score] of state next-strongest
            [set next-strongest f]
        ]
        [set next-strongest f]
    ]
    [
      ; 如果这个国家的分数比我低
      set temp-rank temp-rank + 1 ; 我的排名提升1
      ifelse next-weakest > 0
        [
          ; 如果该国家的分数高于当前的最高分数(如果已指定最弱)
          if other-score > [score] of state next-weakest
            [set next-weakest f]
        ]
        [set next-weakest f]
    ]
  ]

  ; 相应地更新策略
  if ranking != temp-rank
  [
    ; 如果级别发生变化
    set flag true                       ; 运行
    set ranking temp-rank               ; 确定级别
    set change-count change-count + 1   ; 增加改变次数
    foreach [who] of link-neighbors
    ; 和所有邻国合作，看概率确定最终是否合作
    [ f ->
      let random-x random-normal 0 1
      let sigma 1
      ifelse (random-x <= sigma-multiple * sigma) and (random-x >= (- sigma-multiple) * sigma)
        ; 68.26%...1
        ; 95.44%合作 mean +- 2标准差
        ; 99.74%...3
        ; 假设突发事件导致无法合作
        [table:put play-table f "cooperate"]; 合作
        [table:put play-table f "defect"]   ; 背叛
    ]
  ]
  ifelse CC-win-win = false
  [; 背叛相对自己强一位/相对自己弱一位，同样看概率
    let random-y random-normal 0 1
    let sigma 1
    if next-strongest > 0 [
      ifelse (random-y <= sigma-multiple * sigma) and (random-y >= (- sigma-multiple) * sigma)
        [table:put play-table next-strongest "defect"]; 背叛
        [table:put play-table next-strongest "cooperate"]; 合作
    ]
    if next-weakest > 0 [
      ifelse (random-y <= sigma-multiple * sigma) and (random-y >= (- sigma-multiple) * sigma)
        [table:put play-table next-weakest "defect"]; 背叛
        [table:put play-table next-weakest "cooperate"]; 合作
    ]
  ]
  [
    ; 外力介入（如外部机构监督和强制执行合作），建立互信并建立可持续的合作
    if next-strongest > 0 [table:put play-table next-strongest "cooperate"]; 合作
    if next-weakest > 0 [table:put play-table next-weakest "cooperate"]; 合作
  ]

  ; 更新霸权国
  ifelse next-strongest = -1
    ; 如果不存在最强，我即为霸权
    [set hegemon true]
    [set hegemon false]
end

to compute-payoff
  ; 根据每对对象的行动计算收益
  ; 当前收益矩阵为:
  ;             合作               背叛
  ; 合作 cc-score,cc-score  cd-score,dc-score
  ; 背叛 dc-score,cd-score  dd-score,dd-score
  ; 竖行为我 在前

  let my-index who
  ; 定标识符 类似ID
  foreach [who] of link-neighbors
  [ f ->
    ; 获取存储的合作背叛信息
    let my-play table:get play-table f
    let partner-action [table:get play-table my-index] of state f
    ifelse my-play = "cooperate"
    [
      ifelse partner-action = "cooperate"
        [set score score + cc-score]; Cooperate / Cooperate 收益
        [set score score + cd-score]; Cooperate / Defect 收益
    ]
    [
      ifelse partner-action = "cooperate"
        [set score score + dc-score]; Defect / Cooperate 收益
        [set score score + dd-score]; Defect / Defect 收益
    ]

    if TFT = true
      ; 如果选择以牙还牙方式
      [table:put play-table f partner-action] ; 以牙还牙，模仿伙伴行为
  ]
  set label precision score 1
end

to update-tit-for-tat
  ; 对于每个国家，将它们的操作默认为对应接壤国家的最后一个操作，即模仿
  let my-index who
  ; 定标识符 类似ID
  foreach [who] of link-neighbors
  [ f ->
    let new-play [table:get play-table my-index] of state f
    table:put play-table f new-play
  ]
end

to update-color
  ifelse hegemon = true
  [set color red]
  [set color green]
end

to toggle-labels
  let labels-on [label] of one-of states
  ifelse labels-on = ""
  [
    ask states [set label precision score 1]
  ]
  [
    ask states [set label ""]
  ]
end

; --------------------
; 绘图程序
; --------------------

to update-plot
  set-current-plot "Mean-payoffs"
  set-current-plot-pen "Hegemons"
  plot mean [score] of states with [hegemon]    ; 画霸权均值
  set-current-plot-pen "Non-hegemons"
  plot mean [score] of states with [not hegemon]; 画非霸权均值

  set-current-plot "Scores-histogram"
  set-plot-x-range min [score] of states max [score] of states
  set-histogram-num-bars 10
  histogram [score] of states                   ; 分数直方图

  set-current-plot "HegemonsCount"
  plot count states with [hegemon]              ; 画霸权国总数
end


; -------------------------------------
; 参数扫描和导出程序
; -------------------------------------

; 编写自己的参数扫描来避免加载并实现对模型输出的更好控制

to go-for-sweep
  set flag false                   ; 停止符
  ask states [update-assessments]  ; 更新评估
  ask states [compute-payoff]      ; 计算收益
  if TFT = true
    ; 如果选择以牙还牙方式
    [ask states [update-tit-for-tat]]  ; 模仿对方
  ask states [update-color]

  if not flag [stop]               ; 判断停止
  tick

  update-plot
end

to param-sweep
  file-open user-new-file
  file-type "Iteration,Name,Initial_Hegemon,Hegemon,Initial_Score,Score,Change_Count\n"
  file-close
  set iteration 0
  ;set score-dist "Normal"
  ;repeat 1000 [
    ;if iteration = 500 [set score-dist "Exponential"]
    ;prep-model
    ;repeat 60 [go-for-sweep]
    ;export-states               ; 导出结果
    ;set iteration iteration + 1
  ;]
  set score-dist "Norm-GDP" ;或者 Sum-KM2
  repeat 1000 [
    prep-model
    repeat 60 [go-for-sweep]
    export-states               ; 导出结果
    set iteration iteration + 1
  ]
end

to export-states
  file-open "Output.csv"
  ask states [
    ; 文件类型的词行为","
    file-type word iteration ","
    file-type word name ","
    file-type word init-hegemon ","
    file-type word hegemon ","
    file-type word init-score ","
    file-type word score ","
    file-type word change-count " \n"
  ]
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
328
45
1285
535
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-36
36
-18
18
0
0
1
ticks
30.0

CHOOSER
91
227
229
272
score-dist
score-dist
"Normal" "Exponential" "Norm-GDP" "Sum-KM2"
1

BUTTON
22
87
95
120
初始化
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
149
336
313
369
导出国家关系csv文件
export-links
NIL
1
T
OBSERVER
NIL
E
NIL
NIL
1

BUTTON
177
135
315
168
赋分并判断区域霸权
prep-model
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

BUTTON
108
87
195
120
持续运行
go
T
1
T
OBSERVER
NIL
C
NIL
NIL
1

BUTTON
209
87
296
120
运行一次
go
NIL
1
T
OBSERVER
NIL
O
NIL
NIL
1

BUTTON
9
134
158
167
显示/消除分数注记
toggle-labels
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

BUTTON
1318
660
1488
693
参数（多轮）扫描分析
param-sweep
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
1

MONITOR
12
429
102
474
区域霸权国数
count states with [hegemon]
17
1
11

PLOT
832
545
1107
696
Mean-payoffs
NIL
平均分数
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Hegemons" 1.0 0 -2674135 true "" ""
"Non-hegemons" 1.0 0 -10899396 true "" ""

PLOT
1300
232
1500
382
Scores-histogram
分数
国家个数
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1300
45
1499
195
HegemonsCount
NIL
霸权国数
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

BUTTON
16
336
130
369
显示国家关系
print-links
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

OUTPUT
377
543
762
697
12

MONITOR
136
430
201
475
自动轮数
iteration
17
1
11

MONITOR
237
430
302
475
运行？
flag
17
1
11

TEXTBOX
3
44
423
78
通过初始化载入数据并生成网络，赋分后运行
16
0.0
1

TEXTBOX
91
304
241
322
显示/导出国家关系
16
0.0
1

TEXTBOX
4
282
328
308
--------------------------------------------------
12
15.0
1

TEXTBOX
3
380
336
398
--------------------------------------------------
12
15.0
1

TEXTBOX
3
10
378
49
--------------------------------------------------
12
15.0
1

TEXTBOX
386
12
1236
62
国际关系中的重复囚徒困境博弈——模拟接壤国家区域霸权竞争驱动的双边关系
24
125.0
1

TEXTBOX
96
402
246
420
相关状态参数监视
16
0.0
1

TEXTBOX
3
592
324
631
--------------------------------------------------
12
15.0
1

TEXTBOX
1349
624
1465
658
自动多轮次模拟\n并将结果导出
16
0.0
1

TEXTBOX
95
200
232
228
选择赋初始分方式
16
0.0
1

TEXTBOX
3
181
324
199
--------------------------------------------------
12
15.0
1

TEXTBOX
2
688
344
706
--------------------------------------------------
12
15.0
1

TEXTBOX
325
571
359
673
网国\n络家\n中相\n接互\n壤关\n　系
16
0.0
1

TEXTBOX
780
560
816
679
区霸\n域权\n霸国\n权平\n国均\n与收\n非益
16
0.0
1

TEXTBOX
1341
15
1508
49
区域霸权国数量
16
0.0
1

TEXTBOX
1335
204
1485
222
分数分布直方图
16
0.0
1

MONITOR
10
489
139
534
最大分数区域霸权国
[name] of states with [score = max [score] of states with [hegemon]]
17
1
11

MONITOR
174
489
303
534
区域霸权国最大分数
max [score] of states with [hegemon]
1
1
11

SWITCH
39
649
129
682
TFT
TFT
0
1
-1000

SLIDER
1314
433
1486
466
cc-score
cc-score
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
1315
481
1487
514
dd-score
dd-score
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
1315
529
1487
562
dc-score
dc-score
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
1315
575
1487
608
cd-score
cd-score
0
10
0.0
1
1
NIL
HORIZONTAL

TEXTBOX
1289
389
1524
428
----------------------------------
12
15.0
1

TEXTBOX
1295
407
1496
441
设置合作/背叛收益矩阵参数
16
0.0
1

TEXTBOX
1288
612
1508
630
----------------------------------
12
15.0
1

INPUTBOX
1236
618
1286
678
sigma-multiple
2.0
1
0
Number

TEXTBOX
1127
557
1296
627
输入标准差倍数\n突发事件导致合作失败\n处理类型导致背叛失败\n不出现概率
16
0.0
1

BUTTON
8
550
192
583
观察最大分数区域霸权国
watch-most-hegemon
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

BUTTON
205
550
302
583
停止观察
stop-watching
NIL
1
T
OBSERVER
NIL
X
NIL
NIL
1

SWITCH
162
649
295
682
CC-win-win
CC-win-win
1
1
-1000

TEXTBOX
68
608
268
642
选择是否“以牙还牙”\n以及是否“外力介入双赢”
16
0.0
1

TEXTBOX
1130
629
1220
680
3 -> 99.74%\n2 -> 95.44%\n1 -> 68.26%
16
0.0
1

TEXTBOX
1291
692
1524
718
----------------------------------
12
15.0
1

TEXTBOX
1396
14
1546
32
NIL
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

本模型为武汉大学遥感信息工程学院2020级本科生黄梓涛为完成贾涛老师《地理建模方法》课程结课要求编写的Netlogo模型。
在国际关系中，邻国之间的双边关系会受到区域霸权竞争的严重影响。当各国争夺地区主导地位时，其与邻国的互动可能受到战略关切、资源配置和地缘政治定位的驱动。为了更好地理解这一现象，将囚徒困境的概念与国际关系中地缘政治竞争相结合，我们可以在NetLogo中创建一个简单的基于代理的模型，主题为**模拟接壤国家区域霸权竞争驱动的双边关系**。
经典的博弈论问题“囚徒困境”经常被用于国际关系研究中以模拟国家之间的互动。囚徒困境是博弈论中经典的问题之一，通常描述为两个囚犯被捕，但警方缺乏足够的证据来定罪。警方将每个囚犯单独关押，并向他们提供一个选择：合作或背叛。如果两个囚犯都选择合作，那么他们会得到轻判；如果两个囚犯都选择背叛，那么他们会得到重判；如果一个囚犯选择背叛而另一个选择合作，那么背叛的囚犯将会被释放，而合作的囚犯将会得到重判。囚徒困境的一个重要结论是，在没有外部机构监督和强制执行合作的情况下，囚徒困境的参与者通常会选择背叛，这会导致不利的结果。然而，当参与者有机会建立互信并建立可持续的合作时，囚徒困境的结果可能会得到改善。
在国际关系领域中，一些大国之间的双边关系受到了这些大国在某个地理区域内的霸权地位的影响。这些大国之间的互动不仅受到彼此的利益和意识形态等因素的影响，同时还受到这些国家在特定区域内的实力对比的影响。在这种情况下，一些大国可能会试图在某个地理区域内扩大自己的影响力，从而在双边互动中占据更有利的地位。这种双边互动的结果，可能会影响到整个地理区域的政治和经济发展，进而影响到国际体系的稳定和平衡。
在本模型中，在使用 GIS 扩展派生的基于现实世界地理数据的国家级代理网络中实现了一个重复囚徒困境模型，并模拟了接壤国家之间的区域霸权驱动的局部互动，可以观察到各国家代理通过与各方邻国的单独决策方案实施后最终获得的收益与区域地位变化。

## HOW IT WORKS

### 国家代理网络生成
1. 取每个国家Ploygon的质心坐标作为代理坐标生成国家代理，以确定网络节点；
2. 在任何两个共享边界的国家之间建立联系；
3. 将每个未连接的国家连接到最近的两个国家来避免孤岛；
4. 手动整理那些因Shapefile文件问题导致本应连接但未连接的联系。

### 赋初始分与判断区域霸权
1. 赋初始分通过四种方式实现，包括标准正态分布随机赋分、均值为10的指数分布随机赋分、Shapefile文件属性字段中的标准GDP赋分和Shapefile文件属性字段中的国土总面积赋分等；
2. 判断霸权的方式为，在连接的邻居中（含本身）初始分数最大即为霸权。

### 模拟运行
1. 设置程序停止符，停止条件为局部相对排名不变；
2. 更新代理评估，评估所有的网络邻居，以找到整体的局部排名和相对自己强一位/相对自己弱一位的邻居。同时相应地更新策略，对单个国家而言，相对排位根据情况变化，和所有邻国合作，但并非绝对，需要看概率确定最终是否合作（如可能会出现突发事件导致无法合作等），概率函数选取的是标准正态分布（大概率选择合作）。如果有外力介入（如外部机构监督和强制执行合作），建立互信并建立可持续的合作，开启了合作共赢模式，则对相对自己强一位/相对自己弱一位的国家均用合作方式。如果没有，则背叛相对自己强一位/相对自己弱一位，同样看概率（如执政党理性或非理性或其他利益考量等），概率函数同样选取的是标准正态分布（大概率选择背叛）；
3. 计算收益，根据每对网络对象的行动计算收益，收益矩阵为
			合作                              背叛
	合作 cc-score,cc-score  cd-score,dc-score
	背叛 dc-score,cd-score  dd-score,dd-score
4. 模仿对方，如果选择了以牙还牙方式（Tit for Tat），就按策略方式对对策表进行更新，在该策略中，一个人的选择依赖于上一轮对手的选择。如果对手合作，它会合作；如果对手背叛，它也会背叛。
5. 参数扫描，通过自动多轮次的模拟，生成多次模拟该过程的结果并导出为csv文件，得到大量实验模拟结果以便分析。

## HOW TO USE IT

### 按钮
#### 初始化
加载并绘制Shapefile数据，生成国家代理并建立交互网络

#### 持续运行
多次更新评估与计算收益，更新绘图，停止条件为局部区域相对排名不变（注：需先点击赋分并判断区域霸权）

#### 运行一次
单次更新评估与计算收益，更新绘图（注：需先点击赋分并判断区域霸权）

#### 显示/消除分数注记
显示/消除当前网络中节点的当前分数标签

#### 赋分并判断区域霸权
根据所选的赋初始分方式给网络各节点赋分，并对每一节点进行是否邻域最大判断，区域霸权国用加红的五角星表示

#### 显示国家关系
在输出区输出当前网络中接壤国家相互关系

#### 导出国家关系csv文件
在nlogo文件同目录路径处生成当前网络中接壤国家相互关系的csv文件

#### 观察最大分数区域霸权国
聚焦拥有最大分数的区域霸权国，并调出对应视图与属性窗口

#### 停止观察
恢复未观察状态，关闭视图与属性窗口

#### 参数（多轮）扫描分析
自动多轮随机赋分值模拟多次接壤国家区域霸权竞争驱动的双边关系（500次标准正态分布随机赋分，500次均值为10的指数分布随机赋分，每次运行60遍）
### 滑块
#### 设置合作/背叛收益矩阵参数
"cc-score"为两者均选择合作则得相应分数
"dd-score"为两者均选择背叛则得相应分数
"dc-score"为一方选择合作而选择背叛的另一方得相应分数
"cd-score"为一方选择背叛而选择合作的另一方得相应分数
### 开关
#### TFT开关
开则选择采用“以牙还牙”方式，选择依赖于上一轮对方的选择，对方上一轮选择了什么方案己方这一轮就选择什么方案，关则无此策略过程

#### CC-win-win开关
开则选择采用“合作共赢”方式，对相对自己强一位/相对自己弱一位的国家均用合作方式，关则无此策略过程
### 选择器
#### 选择赋初始分的方式，包括：
标准正态分布随机赋分
均值为10的指数分布随机赋分
Shapefile文件属性字段中的标准GDP赋分
Shapefile文件属性字段中的国土总面积赋分
### 输入框
#### 输入标准正态分布标准差倍数，出现概率对应为：
1->68.26%
2->95.44%
3->99.74%
其他数字->详见对应概率表格
### 监视器
#### 霸权国数
当前网络中区域霸权国数量

#### 自动轮数
参数（多轮）扫描分析自动运行的当前轮数

#### 运行？
是否到达持续运行（未达到停止判定）条件

#### 最大分数区域霸权国
当前网络中最大分数的区域霸权国的名称

#### 区域霸权国最大分数
当前网络中最大分数的区域霸权国的分数
### 图
#### 区域霸权国数量
区域霸权国数随模拟运行次数变化图，横坐标为模拟运行次数，纵坐标为区域霸权国数

#### 分数分布直方图
当前网络中各国家分数的分布直方图，横坐标为各种分数（限制为10个区间），纵坐标为对应国家个数

#### 区域霸权国与非霸权国平均收益
区域霸权国与非霸权国平均收益随模拟运行次数变化图，横坐标为模拟运行次数，纵坐标为区域霸权国与非霸权国平均收益，红色为区域霸权国，绿色为非霸权国
### 输出区
输出当前网络中接壤国家相互关系

## EXTENDING THE MODEL

优化和创新，包括以下几点：
1. 人工智能技术：可以引入机器学习或其他人工智能技术，如强化学习、深度学习等，来优化参与者的策略，使得模拟更加准确，同时可以探讨人工智能在国际关系中的应用。
2. 网络结构：可以将参与者之间的关系构建成特定网络结构，如小世界网络、无标度网络等，通过研究网络结构对博弈结果的影响，探讨网络结构在国际关系中的作用。
3. 真实模拟：为了更好地模拟现实世界的复杂性，可以根据需要向模型中添加更多变量，例如贸易、军事实力、外交政策、文化交流、国际组织成员资格等。同时可以考虑引入国家内部因素，如政治制度、经济发展水平和民族关系，以更好地理解国家决策和地缘政治竞争的动态。
4. 合作与背叛策略：根据经典囚徒困境策略（如以牙还牙、慷慨、怀疑等）为代理设计更多种合作与背叛策略。这将使模型能够更好地反映国家之间的战略互动。
5. 多层次互动：研究国家之间的双边关系和多边关系，以及这些关系如何相互影响地缘政治竞争。
6. 模拟不同国际体系：尝试在不同的国际体系下（如现实主义、自由主义或建构主义）对模型进行调整，以探究这些理论框架对地缘政治竞争的影响。
7. 敏感性分析和参数优化：对模型的参数进行敏感性分析，以更好地理解各种因素对模型输出的影响。此外，可以尝试通过参数优化来提高模型的预测能力和准确性。
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
