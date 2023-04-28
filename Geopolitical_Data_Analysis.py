import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# 读取CSV文件
data = pd.read_csv('Output_GDP.csv', dtype=object)

# 将字符串类型的布尔值转换为布尔类型
data['Initial_Hegemon'] = data['Initial_Hegemon'].map({'TRUE': True, 'FALSE': False, 'true': True, 'false': False})
data['Hegemon'] = data['Hegemon'].map({'TRUE': True, 'FALSE': False, 'true': True, 'false': False})

# 将字符串类型的数值转换为浮点数
data['Initial_Score'] = data['Initial_Score'].astype(float)
data['Score'] = data['Score'].astype(float)
data['Change_Count'] = data['Change_Count'].astype(int)

# 1. 对每类Iteration中霸权非霸权之间的转换以及非霸权霸权之间的转换进行数据统计分析
transition_counts = data.groupby('Iteration').apply(lambda x: pd.Series({
    'Hegemon_to_NonHegemon': len(x[(x['Initial_Hegemon'] == True) & (x['Hegemon'] == False)]),
    'NonHegemon_to_Hegemon': len(x[(x['Initial_Hegemon'] == False) & (x['Hegemon'] == True)]),
})).reset_index()

print(transition_counts)
print('###############################################################################################################')

# 2. 计算每个国家在所有迭代中的平均得分变化和平均Change_Count
country_stats = data.groupby('Name').agg(
    Avg_Score_Change=('Score', 'mean'),
    Avg_Change_Count=('Change_Count', 'mean')
).reset_index()

print(country_stats)
print('###############################################################################################################')

# 找到平均变化分数和平均变化次数的Top 10国家
top_10_score_change = country_stats.nlargest(10, 'Avg_Score_Change')
top_10_change_count = country_stats.nlargest(10, 'Avg_Change_Count')

# 创建双Y轴图
fig, ax1 = plt.subplots(figsize=(14, 6))

# 设置X轴和第一个Y轴
ax1.set_xlabel('国家', fontproperties="SimHei")
ax1.set_ylabel('平均变化分数', fontproperties="SimHei", color='tab:blue')
ax1.bar(top_10_score_change['Name'], top_10_score_change['Avg_Score_Change'], color='tab:blue', width=-0.4, alpha=0.7, label='平均变化分数', align='edge')
ax1.tick_params(axis='y', labelcolor='tab:blue')

# 设置第二个Y轴
ax2 = ax1.twinx()
ax2.set_ylabel('平均变化次数', fontproperties="SimHei", color='tab:red')
ax2.bar(top_10_change_count['Name'], top_10_change_count['Avg_Change_Count'], color='tab:red', width=0.4, alpha=0.7, label='平均变化次数', align='edge')
ax2.tick_params(axis='y', labelcolor='tab:red')

# 设置标题和图例
plt.title('平均变化分数和平均变化次数Top 10国家', fontproperties="SimHei")
ax1.legend(loc='upper left', prop={'family':'SimHei'})
ax2.legend(loc='upper right', prop={'family':'SimHei'})

# 调整X轴标签的位置，以避免重叠
plt.xticks(np.arange(len(top_10_score_change)), top_10_score_change['Name'], rotation=45, ha='right')

plt.show()

# 3. 使用散点图进行可视化
plt.scatter(country_stats['Avg_Score_Change'], country_stats['Avg_Change_Count'])

# 找到平均变化分数最大和平均变化次数最大的国家
max_score_change_country = country_stats.loc[country_stats['Avg_Score_Change'].idxmax()]['Name']
max_change_count_country = country_stats.loc[country_stats['Avg_Change_Count'].idxmax()]['Name']

# 标出这两个国家的名称
plt.annotate(max_score_change_country,
             (country_stats.loc[country_stats['Avg_Score_Change'].idxmax()]['Avg_Score_Change'],
              country_stats.loc[country_stats['Avg_Score_Change'].idxmax()]['Avg_Change_Count']))

plt.annotate(max_change_count_country,
             (country_stats.loc[country_stats['Avg_Change_Count'].idxmax()]['Avg_Score_Change'],
              country_stats.loc[country_stats['Avg_Change_Count'].idxmax()]['Avg_Change_Count']))

plt.xlabel('平均变化分数', fontproperties="SimHei")
plt.ylabel('平均变化次数', fontproperties="SimHei")
plt.title('平均变化分数和平均变化次数散点图', fontproperties="SimHei")

plt.show()

# 4. 描述性统计分析
# 计算平均值、标准差、最大值和最小值
descriptive_stats = transition_counts.describe().loc[['mean', 'std', 'max', 'min'], :]
print(descriptive_stats)

# 5. 找出每轮初始最大分数国和最终最大分数国，统计所有Iteration中有多少次最大分数国变化的数据
initial_max_score_country = data.loc[data.groupby('Iteration')['Initial_Score'].idxmax()][['Iteration', 'Name']]
final_max_score_country = data.loc[data.groupby('Iteration')['Score'].idxmax()][['Iteration', 'Name']]

# 设置相同的索引
initial_max_score_country.set_index('Iteration', inplace=True)
final_max_score_country.set_index('Iteration', inplace=True)

# 合并初始和最终最大分数国的数据，并比较它们
country_changes_df = pd.concat([initial_max_score_country, final_max_score_country], axis=1)
country_changes_df.columns = ['Initial_Name', 'Final_Name']

# 统计所有Iteration中最大分数国变化的次数
country_changes = (country_changes_df['Initial_Name'] != country_changes_df['Final_Name']).sum()
print(f"最大分数国变化的次数：{country_changes}")
print('###############################################################################################################')

# 6. 找出每轮最终最大分数国以及分数，同时对所有轮数数据进行按国家名称聚类
max_score_countries = data.loc[data.groupby('Iteration')['Score'].idxmax()][['Name', 'Score']]

# 统计每个国家出现的次数
country_counts = max_score_countries['Name'].value_counts()

# 按照出现次数降序排列
country_counts_sorted = country_counts.sort_values(ascending=False)

# 绘制直方图
plt.bar(country_counts_sorted.index, country_counts_sorted.values)

plt.xlabel('国家名称', fontproperties="SimHei")
plt.ylabel('出现次数', fontproperties="SimHei")
plt.title('每轮最终最大分数国出现次数直方图', fontproperties="SimHei")

plt.show()

max_score_stats = max_score_countries.groupby('Name').describe()['Score'].loc[:, ['mean', 'std', 'min', 'max']]
print(max_score_stats)
print('###############################################################################################################')

######################################################### WorldNetwork分析 #####################################################
# import pandas as pd
# import networkx as nx
# import matplotlib.pyplot as plt
#
# # 1. 使用pandas读取CSV文件
# data = pd.read_csv('WorldNetwork.csv')
#
# # 2. 使用networkx创建一个无向图
# G = nx.Graph()
#
# # 3. 将数据添加到无向图中
# for _, row in data.iterrows():
#     G.add_edge(row['Source'], row['Destination'])
#
# # 4. 计算图的一些基本统计信息
# print(f"节点数量：{G.number_of_nodes()}")
# print(f"边数量：{G.number_of_edges()}")
# print(f"平均度：{sum(dict(G.degree()).values()) / float(G.number_of_nodes())}")
#
# # 找到具有最多边的Top 10个国家
# degree_dict = dict(G.degree())
# top_10_countries = sorted(degree_dict, key=degree_dict.get, reverse=True)[:10]
# top_10_degrees = [degree_dict[country] for country in top_10_countries]
# print(f"具有最多边的Top 10个国家：{top_10_countries}")
# print(f"分别有：{top_10_degrees}")
#
# # 5. 使用networkx和matplotlib绘制图形
# # plt.figure(figsize=(12, 12))
# # pos = nx.spring_layout(G, seed=42)
# # nx.draw(G, pos, node_size=50, node_color="blue", edge_color="gray", font_size=8, with_labels=True, alpha=0.8)
# # 设置节点属性
# node_sizes = [d * 50 for n, d in G.degree()]
#
# # 绘制网络图
# plt.figure(figsize=(12, 12))
# pos = nx.random_layout(G)
# nx.draw_networkx_nodes(G, pos, node_size=node_sizes, node_color="#1f78b4", alpha=0.8, edgecolors='k')
# nx.draw_networkx_edges(G, pos, alpha=0.5, edge_color='gray')
# nx.draw_networkx_labels(G, pos, font_size=8, font_family='Arial', font_weight='bold', labels={n:n for n in G.nodes()})
#
# # 设置坐标轴
# plt.axis('off')
#
# # 突出显示Top 10个国家
# nx.draw_networkx_nodes(G, pos, nodelist=top_10_countries, node_color="red", node_size=100, alpha=1)
# plt.show()
# # 绘制柱状图
# plt.figure(figsize=(12, 6))
# plt.bar(top_10_countries, top_10_degrees)
# plt.xlabel('国家', fontproperties="SimHei")
# plt.ylabel('边数量', fontproperties="SimHei")
# plt.title('具有最多边的Top 10国家', fontproperties="SimHei")
# plt.show()