import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

# Plot styling
sns.set_theme(style="whitegrid")
plt.rcParams['figure.figsize'] = (12, 5)
plt.rcParams['font.size'] = 12

# Load data
df = pd.read_csv('data.csv', encoding='latin1')

# Clean data
df = df.dropna(subset=['CustomerID'])
df = df[df['Quantity'] > 0]
df = df[df['UnitPrice'] > 0]
df = df[~df['InvoiceNo'].astype(str).str.startswith('C')]

# Feature engineering
df['Revenue'] = df['Quantity'] * df['UnitPrice']
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'])
df['Month'] = df['InvoiceDate'].dt.to_period('M')
df['Hour'] = df['InvoiceDate'].dt.hour
df['DayOfWeek'] = df['InvoiceDate'].dt.day_name()
df['Date'] = df['InvoiceDate'].dt.date

print("=" * 55)
print("   E-COMMERCE FUNNEL ANALYSIS — KEY METRICS")
print("=" * 55)
print(f"  Total Transactions : {len(df):,}")
print(f"  Unique Orders      : {df['InvoiceNo'].nunique():,}")
print(f"  Unique Customers   : {df['CustomerID'].nunique():,}")
print(f"  Unique Products    : {df['StockCode'].nunique():,}")
print(f"  Countries          : {df['Country'].nunique():,}")
print(f"  Total Revenue      : £{df['Revenue'].sum():,.2f}")
print(f"  Avg Order Value    : £{df.groupby('InvoiceNo')['Revenue'].sum().mean():,.2f}")
print("=" * 55)
print("Data loaded successfully!")


# ── Chart 1: Monthly Revenue Trend
monthly = df.groupby('Month')['Revenue'].sum().reset_index()
monthly['Month'] = monthly['Month'].astype(str)

plt.figure(figsize=(14, 5))
plt.plot(monthly['Month'], monthly['Revenue'], 
         color='#3498db', linewidth=2.5, marker='o', markersize=6)
plt.fill_between(range(len(monthly)), monthly['Revenue'], 
                 alpha=0.1, color='#3498db')
plt.title('Monthly Revenue Trend', fontsize=15, fontweight='bold')
plt.xlabel('Month')
plt.ylabel('Revenue (£)')
plt.xticks(range(len(monthly)), monthly['Month'], rotation=45)
plt.tight_layout()
plt.savefig('chart1_monthly_revenue.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 1 saved!")

# ── Chart 2: Top 10 Countries by Revenue 
country_rev = df.groupby('Country')['Revenue'].sum().sort_values(ascending=False).head(10)

plt.figure(figsize=(12, 5))
bars = plt.barh(country_rev.index[::-1], country_rev.values[::-1],
                color='#2ecc71', edgecolor='black')
plt.title('Top 10 Countries by Revenue', fontsize=15, fontweight='bold')
plt.xlabel('Revenue (£)')
for bar, val in zip(bars, country_rev.values[::-1]):
    plt.text(val + 1000, bar.get_y() + bar.get_height()/2,
             f'£{val:,.0f}', va='center', fontsize=10)
plt.tight_layout()
plt.savefig('chart2_top_countries.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 2 saved!")



# ── Chart 3: Hourly Purchase Pattern 
hourly = df.groupby('Hour')['InvoiceNo'].nunique()

plt.figure(figsize=(12, 5))
bars = plt.bar(hourly.index, hourly.values,
               color=['#e74c3c' if v == hourly.max() else '#3498db' for v in hourly.values],
               edgecolor='black')
plt.title('Orders by Hour of Day', fontsize=15, fontweight='bold')
plt.xlabel('Hour of Day')
plt.ylabel('Number of Orders')
plt.xticks(range(0, 24))
plt.tight_layout()
plt.savefig('chart3_hourly_pattern.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 3 saved!")

# ── Chart 4: Revenue by Day of Week 
day_order = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
day_rev = df.groupby('DayOfWeek')['Revenue'].sum().reindex(day_order)

plt.figure(figsize=(12, 5))
bars = plt.bar(day_rev.index, day_rev.values,
               color=['#e74c3c' if v == day_rev.max() else '#9b59b6' for v in day_rev.values],
               edgecolor='black')
plt.title('Revenue by Day of Week', fontsize=15, fontweight='bold')
plt.xlabel('Day of Week')
plt.ylabel('Revenue (£)')
for bar, val in zip(bars, day_rev.values):
    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 500,
             f'£{val:,.0f}', ha='center', fontsize=9, fontweight='bold')
plt.tight_layout()
plt.savefig('chart4_day_of_week.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 4 saved!")


# ── Chart 5: Top 10 Products by Revenue
top_products = df.groupby('Description')['Revenue'].sum().sort_values(ascending=False).head(10)

plt.figure(figsize=(12, 6))
bars = plt.barh(top_products.index[::-1], top_products.values[::-1],
                color='#f39c12', edgecolor='black')
plt.title('Top 10 Products by Revenue', fontsize=15, fontweight='bold')
plt.xlabel('Revenue (£)')
for bar, val in zip(bars, top_products.values[::-1]):
    plt.text(val + 100, bar.get_y() + bar.get_height()/2,
             f'£{val:,.0f}', va='center', fontsize=9)
plt.tight_layout()
plt.savefig('chart5_top_products.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 5 saved!")

# ── Chart 6: Customer Segmentation by Spend
customer_spend = df.groupby('CustomerID')['Revenue'].sum()
segments = pd.cut(customer_spend,
                  bins=[0, 500, 1000, 5000, float('inf')],
                  labels=['Entry (<£500)', 'Regular (£500-1K)', 
                          'Premium (£1K-5K)', 'VIP (£5K+)'])
seg_counts = segments.value_counts()

plt.figure(figsize=(10, 5))
colors = ['#2ecc71', '#3498db', '#f39c12', '#e74c3c']
bars = plt.bar(seg_counts.index, seg_counts.values,
               color=colors, edgecolor='black')
plt.title('Customer Segmentation by Spend', fontsize=15, fontweight='bold')
plt.xlabel('Customer Segment')
plt.ylabel('Number of Customers')
for bar, val in zip(bars, seg_counts.values):
    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 5,
             str(val), ha='center', fontsize=12, fontweight='bold')
plt.tight_layout()
plt.savefig('chart6_customer_segments.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 6 saved!")



# ── Chart 7: RFM Segment Distribution 
snapshot_date = df['Date'].max()
rfm = df.groupby('CustomerID').agg({
    'Date': lambda x: (snapshot_date - x.max()).days,
    'InvoiceNo': 'nunique',
    'Revenue': 'sum'
}).reset_index()
rfm.columns = ['CustomerID', 'Recency', 'Frequency', 'Monetary']

rfm['R'] = pd.qcut(rfm['Recency'], 5, labels=[5,4,3,2,1])
rfm['F'] = pd.qcut(rfm['Frequency'].rank(method='first'), 5, labels=[1,2,3,4,5])
rfm['M'] = pd.qcut(rfm['Monetary'], 5, labels=[1,2,3,4,5])
rfm['RFM_Score'] = rfm['R'].astype(int) + rfm['F'].astype(int) + rfm['M'].astype(int)

def segment(score):
    if score >= 13: return 'Champions'
    elif score >= 10: return 'Loyal'
    elif score >= 7: return 'Potential'
    elif score >= 5: return 'At Risk'
    else: return 'Lost'

rfm['Segment'] = rfm['RFM_Score'].apply(segment)
seg_rev = rfm.groupby('Segment')['Monetary'].sum().sort_values(ascending=False)

plt.figure(figsize=(10, 5))
colors = ['#2ecc71', '#3498db', '#f39c12', '#e74c3c', '#9b59b6']
bars = plt.bar(seg_rev.index, seg_rev.values, color=colors, edgecolor='black')
plt.title('Revenue by RFM Customer Segment', fontsize=15, fontweight='bold')
plt.xlabel('Customer Segment')
plt.ylabel('Total Revenue (£)')
for bar, val in zip(bars, seg_rev.values):
    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 100,
             f'£{val:,.0f}', ha='center', fontsize=10, fontweight='bold')
plt.tight_layout()
plt.savefig('chart7_rfm_segments.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 7 saved!")

# ── Chart 8: Cohort Retention Heatmap 
df['CohortMonth'] = df.groupby('CustomerID')['Month'].transform('min')
df['CohortIndex'] = (df['Month'] - df['CohortMonth']).apply(lambda x: x.n)

cohort = df.groupby(['CohortMonth', 'CohortIndex'])['CustomerID'].nunique().reset_index()
cohort_pivot = cohort.pivot(index='CohortMonth', columns='CohortIndex', values='CustomerID')
cohort_pct = cohort_pivot.divide(cohort_pivot.iloc[:, 0], axis=0) * 100

plt.figure(figsize=(14, 7))
sns.heatmap(cohort_pct.round(1), annot=True, fmt='.1f',
            cmap='RdYlGn', linewidths=0.5,
            cbar_kws={'label': 'Retention Rate %'})
plt.title('Cohort Retention Heatmap\n(% of customers still active by month)',
          fontsize=15, fontweight='bold')
plt.xlabel('Months Since First Purchase')
plt.ylabel('Cohort Month')
plt.tight_layout()
plt.savefig('chart8_cohort_heatmap.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 8 saved!")


# ── Chart 9: Basket Size Distribution
basket = df.groupby('InvoiceNo').agg(
    items=('StockCode', 'nunique'),
    value=('Revenue', 'sum')
).reset_index()

basket['size_group'] = pd.cut(basket['items'],
    bins=[0, 1, 5, 10, float('inf')],
    labels=['1 item', '2-5 items', '6-10 items', '10+ items'])

basket_rev = basket.groupby('size_group', observed=True)['value'].mean()

plt.figure(figsize=(10, 5))
bars = plt.bar(basket_rev.index, basket_rev.values,
               color=['#e74c3c', '#f39c12', '#3498db', '#2ecc71'],
               edgecolor='black', width=0.5)
plt.title('Avg Order Value by Basket Size', fontsize=15, fontweight='bold')
plt.xlabel('Basket Size')
plt.ylabel('Avg Order Value (£)')
for bar, val in zip(bars, basket_rev.values):
    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
             f'£{val:,.0f}', ha='center', fontsize=12, fontweight='bold')
plt.tight_layout()
plt.savefig('chart9_basket_size.png', dpi=150, bbox_inches='tight')
plt.show()
print("Chart 9 saved!")

# ── Chart 10: Dashboard Summary 
fig, axes = plt.subplots(2, 3, figsize=(20, 12))
fig.suptitle('E-Commerce Funnel Analysis Dashboard — UCI Retail Dataset',
             fontsize=20, fontweight='bold', y=1.01)

from matplotlib.image import imread
charts = [
    ('chart1_monthly_revenue.png', 'Monthly Revenue'),
    ('chart2_top_countries.png', 'Top Countries'),
    ('chart3_hourly_pattern.png', 'Hourly Pattern'),
    ('chart6_customer_segments.png', 'Customer Segments'),
    ('chart7_rfm_segments.png', 'RFM Segments'),
    ('chart8_cohort_heatmap.png', 'Cohort Heatmap'),
]
for ax, (path, title) in zip(axes.flatten(), charts):
    try:
        img = imread(path)
        ax.imshow(img)
        ax.set_title(title, fontsize=13, fontweight='bold')
        ax.axis('off')
    except:
        ax.set_visible(False)

plt.tight_layout()
plt.savefig('ECommerce_Dashboard_Summary.png', dpi=150, bbox_inches='tight')
plt.show()

# Key Insights
print("\n" + "=" * 55)
print("      E-COMMERCE — KEY INSIGHTS")
print("=" * 55)
print(f"  Total Revenue          : £{df['Revenue'].sum():,.2f}")
print(f"  Peak Hour              : {df.groupby('Hour')['InvoiceNo'].nunique().idxmax()}:00")
print(f"  Best Day               : {df.groupby('DayOfWeek')['Revenue'].sum().idxmax()}")
print(f"  Top Country            : {df.groupby('Country')['Revenue'].sum().idxmax()}")
print(f"  Champion Customers     : {(rfm['Segment'] == 'Champions').sum()}")
print(f"  Lost Customers         : {(rfm['Segment'] == 'Lost').sum()}")
print(f"  Avg Order Value        : £{basket['value'].mean():,.2f}")
print(f"  Repeat Customer Rate   : {(rfm['Frequency'] > 1).sum() / len(rfm) * 100:.1f}%")
print("=" * 55)
print("Analysis Complete!")